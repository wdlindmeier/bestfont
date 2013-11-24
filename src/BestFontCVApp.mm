#include "cinder/app/AppNative.h"
#include "cinder/app/RendererGl.h"
#include "cinder/Font.h"
#include "cinder/gl/gl.h"
#include "cinder/gl/Texture.h"
#include "cinder/Surface.h"
#include "cinder/Text.h"
#include "cinder/Shape2d.h"
#include "cinder/Path2d.h"
#include "cinder/TriMesh.h"
#include "cinder/gl/Vao.h"
#include "cinder/gl/Vbo.h"
#include "cinder/gl/Shader.h"
#include "cinder/Perlin.h"
#include "cinder/gl/GlslProg.h"
#include "CinderOpenCv.h"

#include "GeneticPopulation.hpp"
#include "GeneticFont.h"
#include "GeneUtilities.hpp"
#include "BestFontConstants.h"

using namespace ci;
using namespace ci::app;
using namespace std;


class BestFontCVApp : public AppNative
{
  public:
    
    BestFontCVApp() : mPopulation(kInitialPopulationSize) {}
    
    void prepareSettings(Settings *settings);
	void setup();
	void draw();
    void mouseDown(MouseEvent event);
    void mouseDrag(MouseEvent event);
    void mouseUp(MouseEvent event);
    
    void update();
	
    Surface         mTargetSurface;
    gl::TextureRef  mTargetTexture;
    
    Surface8u       mTargetSelectionSurf;
    gl::TextureRef  mTargetSelectionTex;

    Vec2i           mMousePositionStart;
    Vec2i           mMousePositionEnd;
    Vec2i           mMousePosition;
    Rectf           mDrawingRect;
    
    Vec2i           mTargetOffset;
    
    GeneticPopulation<GeneticFont> mPopulation;

};

void BestFontCVApp::prepareSettings(Settings *settings)
{
    settings->setWindowSize(kMaxFontX, kMaxFontY);
}

void BestFontCVApp::setup()
{
    /*
    mFontIndex = 0;
    mAvailFonts = [[NSFontManager sharedFontManager] availableFonts];
    NSLog(@"availFonts: %@", mAvailFonts);
    mTestString = "Quick Fox";
    */
    
    mTargetSurface = loadImage(loadResource("gallagher.jpg"));
    mTargetSelectionSurf = mTargetSurface;
    mTargetSelectionTex = gl::Texture::create(mTargetSelectionSurf);
    mTargetTexture = gl::Texture::create(mTargetSurface);
    
    mTargetOffset = Vec2i(100,100);
    
    console() << "mPopulation.size: " << mPopulation.getPopulation().size() << "\n";
}   

#pragma mark - Mouse Input

static ci::Rectf rectFromTwoPos(const ci::Vec2f & posA, const ci::Vec2f & posB)
{
    int x1 = std::min(posA.x, posB.x);
    int x2 = std::max(posA.x, posB.x);
    int y1 = std::min(posA.y, posB.y);
    int y2 = std::max(posA.y, posB.y);
    return ci::Rectf(x1, y1, x2, y2);
}

void BestFontCVApp::mouseDown( MouseEvent event )
{
    mMousePositionStart = event.getPos();
    mDrawingRect = Rectf(mMousePosition.x, mMousePosition.y,
                         mMousePosition.x, mMousePosition.y);
}

void BestFontCVApp::mouseDrag(MouseEvent event)
{
    mMousePosition = event.getPos();
    mDrawingRect = rectFromTwoPos(mMousePosition, mMousePositionStart);
    mMousePositionEnd = mMousePosition;
}

void BestFontCVApp::mouseUp(MouseEvent event)
{
    cv::Mat targetMat = toOcv(mTargetSurface);
    cv::Size inputSize = targetMat.size();
    float x = ci::math<float>::clamp(mDrawingRect.x1 - mTargetOffset.x, 0, inputSize.width);
    float y = ci::math<float>::clamp(mDrawingRect.y1 - mTargetOffset.y, 0, inputSize.height);
    float w = ci::math<float>::clamp(mDrawingRect.getWidth(), 0, inputSize.width - x);
    float h = ci::math<float>::clamp(mDrawingRect.getHeight(), 0, inputSize.height - y);
    cv::Rect cropRect(x, y, w, h);
    cv::Mat targetSelect = targetMat(cropRect);
    
    mTargetSelectionSurf = fromOcv(targetSelect);
    mTargetSelectionTex = gl::Texture::create(mTargetSelectionSurf);
}

void BestFontCVApp::update()
{
    // Evolution:
    mPopulation.runGeneration([&](GeneticFont & font)// -> float
    {
        // Passes the image into the font for comparison
        return font.calculateFitnessScalar(mTargetSelectionSurf);
    });
}

void BestFontCVApp::draw()
{
    gl::enableAlphaBlending();
	gl::clear( Color( 1, 1, 1 ) );
    
    gl::color(ColorAf(1,1,1,1));
    gl::draw(mTargetTexture, Rectf(mTargetOffset.x,
                                   mTargetOffset.y,
                                   mTargetOffset.x + mTargetTexture->getWidth(),
                                   mTargetOffset.y + mTargetTexture->getHeight()));
    
    if (mDrawingRect.getWidth() > 0)
    {
        gl::bindStockShader(gl::ShaderDef().color());
        // Draw the rect
        gl::color(ColorAf(1,1,0,0.5));
        gl::drawSolidRect(mDrawingRect);
    }
    
    gl::color(ColorAf(1,1,1,0.5));
    gl::draw(mTargetSelectionTex);
    
    // TODO:
    // Draw the current fittest
    gl::bindStockShader(gl::ShaderDef().color());
    gl::color(ColorAf(1,0,0,1));
    gl::setDefaultShaderVars();
    
    assert(mPopulation.getPopulation().size() > 0);
    GeneticFont & f = mPopulation.getPopulation()[0];
    f.render();
}

CINDER_APP_NATIVE( BestFontCVApp, RendererGl )
