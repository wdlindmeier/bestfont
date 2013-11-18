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

using namespace ci;
using namespace ci::app;
using namespace std;

class BestFontCVApp : public AppNative {
  public:
	void setup();
	void draw();
    void mouseDown(MouseEvent event);
    void mouseDrag(MouseEvent event);
    //void mouseMove(MouseEvent event);
    //void mouseUp(MouseEvent event);
    
    void update();
	
    Surface         mTargetSurface;
    gl::TextureRef  mTargetTexture;
    
    Surface         mTestSurface;
    gl::TextureRef  mTestTexture;
    std::string     mTestString;
    NSArray *       mAvailFonts;
    int             mFontIndex;
    
    Vec2i mMousePositionStart;
    Vec2i mMousePositionEnd;
    Vec2i mMousePosition;
    Rectf mDrawingRect;

};

void BestFontCVApp::setup()
{
    mFontIndex = 0;
    mAvailFonts = [[NSFontManager sharedFontManager] availableFonts];
    NSLog(@"availFonts: %@", mAvailFonts);
    mTestString = "Quick Fox";
    
    mTargetSurface = loadImage(loadResource("gallagher.jpg"));
    mTargetTexture = gl::Texture::create(mTargetSurface);
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

/*
void BestFontCVApp::mouseMove(MouseEvent event)
{
    mMousePosition = event.getPos();
    mDrawingRect = Rectf(mMousePosition.x, mMousePosition.y,
                         mMousePosition.x, mMousePosition.y);
}
void BestFontCVApp::mouseUp(MouseEvent event)
{
    if (mIsAdding)
    {
        clearSelection();
        finishAdding(event);
    }
    else if (mIsRemoving)
    {
        clearSelection();
        finishRemoving(event);
    }
    else if(mIsJoining)
    {
        finishJoining(event);
    }
    else
    {
        finishRegionSelection(event);
    }
}
 */

void BestFontCVApp::update()
{
    NSString *nextFontName = [mAvailFonts objectAtIndex:mFontIndex];
    string fontName([nextFontName UTF8String]);
    Font nextFont(fontName, 32);
    Surface frameSurf = ci::renderString(mTestString,
                                         nextFont,
                                         Color(0,0,0));
    gl::Texture *nameTex = new gl::Texture(frameSurf);
    mTestTexture = gl::TextureRef(nameTex);
    mFontIndex = (mFontIndex + 1) % mAvailFonts.count;
}

void BestFontCVApp::draw()
{
    gl::enableAlphaBlending();
	gl::clear( Color( 1, 1, 1 ) );
    gl::draw(mTestTexture);
    
    Vec2i targetOffset(100,100);
    gl::color(ColorAf(1,1,1,1));
    gl::draw(mTargetTexture, Rectf(targetOffset.x,
                                   targetOffset.y,
                                   targetOffset.x + mTargetTexture->getWidth(),
                                   targetOffset.y + mTargetTexture->getHeight()));
    
    if (mDrawingRect.getWidth() > 0)
    {
        gl::bindStockShader(gl::ShaderDef().color());
        // Draw the rect
        gl::color(ColorAf(1,1,0,0.5));
        gl::drawSolidRect(mDrawingRect);
    }
}

CINDER_APP_NATIVE( BestFontCVApp, RendererGl )
