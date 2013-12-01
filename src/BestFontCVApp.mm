#include "cinder/app/AppNative.h"
#include "cinder/app/RendererGl.h"
#include "cinder/Font.h"
#include "cinder/gl/gl.h"
#include "cinder/gl/Texture.h"
#include "cinder/Surface.h"
#include "cinder/Channel.h"
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
#include "GeneticConstraints.hpp"

using namespace ci;
using namespace ci::app;
using namespace std;

extern float gMutationRate = 0.05;
extern std::string gDisplayString = "";

class BestFontCVApp : public AppNative
{
  public:
    
    BestFontCVApp() : mPopulation(0) {}
    
    void            prepareSettings(Settings *settings);
	void            setup();
	void            draw();
    void            mouseDown(MouseEvent event);
    void            mouseDrag(MouseEvent event);
    void            mouseUp(MouseEvent event);
    void            keyUp(KeyEvent event);
    void            update();
    std::string     getImageText();
    int             displayInstructions();
    void            restartPopulation();
	
    Surface         mTargetSurface;
    gl::TextureRef  mTargetTexture;
    
    Channel8u       mTargetSelectionChan;
    gl::TextureRef  mTargetSelectionTex;

    Vec2i           mMousePositionStart;
    Vec2i           mMousePositionEnd;
    Vec2i           mMousePosition;
    Rectf           mDrawingRect;
    
    Vec2i           mTargetOffset;
    
    GeneticPopulation<GeneticFont> mPopulation;
    
    bool            mShouldAdvance;

};

void BestFontCVApp::prepareSettings(Settings *settings)
{
    settings->setWindowSize(800, 600);
}

std::string BestFontCVApp::getImageText()
{
    NSAlert *alert = [NSAlert alertWithMessageText:@"What does the image say?\n(case sensitive)"
                                     defaultButton:@"OK"
                                   alternateButton:nil
                                       otherButton:nil
                         informativeTextWithFormat:@""];
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 290, 24)];
    [input setStringValue:@""];
    [input autorelease];
    [alert setAccessoryView:input];
    NSInteger button = [alert runModal];
    if (button == NSAlertDefaultReturn)
    {
        [input validateEditing];
        return std::string([[input stringValue] UTF8String]);
    }
    return "";
}

int BestFontCVApp::displayInstructions()
{
    NSAlert *alert = [NSAlert alertWithMessageText:@"Highlight the Text"
                                     defaultButton:@"OK"
                                   alternateButton:nil
                                       otherButton:nil
                         informativeTextWithFormat:@"Select the text region by dragging your mouse."];
    return (int)[alert runModal];
}

void BestFontCVApp::setup()
{
    mDrawingRect = Rectf(0,0,0,0);
    mShouldAdvance = false;
    
    gMutationRate = 0.05f;

    fs::path filePath = getOpenFilePath();
    mTargetSurface = loadImage(filePath);
    
    mTargetSelectionChan = mTargetSurface.getChannelRed();
    mTargetSelectionTex = gl::Texture::create(Surface8u(mTargetSelectionChan));
    mTargetTexture = gl::Texture::create(mTargetSurface);
    
    GeneticConstraintsRef gc = GeneticConstraints::getSharedConstraints();
    gc->maxPosX = mTargetSelectionChan.getWidth();
    gc->maxPosY = mTargetSelectionChan.getHeight();
    
    mTargetOffset = Vec2i(100,100);
}

#pragma mark - Population

void BestFontCVApp::restartPopulation()
{
    console() << "Restarting\n";
    mPopulation = GeneticPopulation<GeneticFont>(kInitialPopulationSize);
    mShouldAdvance = true;
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
    if (w <= 0 || h <= 0)
    {
        // Abort selection
        mDrawingRect = Rectf(0,0,0,0);
        return;
    }
    
    cv::Rect cropRect(x, y, w, h);
    cv::Mat targetSelect = targetMat(cropRect);
    
    Surface8u targetSelectSurf = fromOcv(targetSelect);
    mTargetSelectionChan = targetSelectSurf.getChannelRed();
    // Crop the target to eliminate any white pixels
    Channel::Iter iter = mTargetSelectionChan.getIter(Area(0,0,w,h));
    int minX = 16000;
    int minY = 16000;
    int maxX = 0;
    int maxY = 0;
    while( iter.line() )
    {
        while( iter.pixel() )
        {
            int val = iter.v();
            if (val < kPxWhitness)
            {
                // This is a pixel
                if (iter.x() < minX) minX = iter.x();
                if (iter.x() > maxX) maxX = iter.x();
                if (iter.y() < minY) minY = iter.y();
                if (iter.y() > maxY) maxY = iter.y();
            }
        }
    }
    if (minX < maxX && minY < maxY)
    {
        int width = maxX - minX;
        int height = maxY - minY;
        Channel8u croppedChannel(width, height);
        croppedChannel.copyFrom(mTargetSelectionChan,
                                Area(Vec2i(minX, minY), Vec2i(maxX, maxY)),
                                Vec2i(-minX, -minY));
        mTargetSelectionChan = croppedChannel;
    }
    
    mTargetSelectionTex = gl::Texture::create(Surface8u(mTargetSelectionChan));
    GeneticConstraintsRef gc = GeneticConstraints::getSharedConstraints();
    gc->maxPosX = mTargetSelectionChan.getWidth();
    gc->maxPosY = mTargetSelectionChan.getHeight();
    
    restartPopulation();
}

#pragma mark - Key Input

void BestFontCVApp::keyUp(cinder::app::KeyEvent event)
{
    if (event.getChar() == ' ')
    {
        restartPopulation();
    }
    else if (event.getCode() == KeyEvent::KEY_UP)
    {
        gMutationRate = gMutationRate + 0.01;
    }
    else if (event.getCode() == KeyEvent::KEY_DOWN)
    {
        gMutationRate = gMutationRate - 0.01;
    }
    console() << "MutationRate: " << gMutationRate << "\n";
}

#pragma mark - App Loop

void BestFontCVApp::update()
{
    if (mPopulation.getPopulation().size() > 0)
    {
        if (mShouldAdvance)
        {
            console() << "Running generation " << mPopulation.getGenerationCount() << "\n";
            
            // Evolution:
            mPopulation.runGeneration([&](GeneticFont & font)// -> float
            {
                // Passes the image into the font for comparison
                return font.calculateFitnessScalar(mTargetSelectionChan);
            });
            // mShouldAdvance = false;
        }
    }
    
    // Waiting to prompt user until the image has been drawn so they can reference it.
    if (getElapsedFrames() > 1 && gDisplayString == "")
    {
        while (gDisplayString == "")
        {
            gDisplayString = getImageText();
        }
        console() << "gDisplayString: " << gDisplayString << "\n";
        displayInstructions();
    }
}

void BestFontCVApp::draw()
{
    gl::enableAlphaBlending();
    // glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
	gl::clear( Color( 1, 1, 1 ) );
    
    if (mDrawingRect.getWidth() > 0)
    {
        // Draw the current selection
        gl::color(ColorAf(0,1,1,0.5));
        gl::draw(mTargetSelectionTex);
    }
    
    gl::color(ColorAf(1,1,1,1));
    gl::draw(mTargetTexture, Rectf(mTargetOffset.x,
                                   mTargetOffset.y,
                                   mTargetOffset.x + mTargetTexture->getWidth(),
                                   mTargetOffset.y + mTargetTexture->getHeight()));
    
    if (mDrawingRect.getWidth() > 0)
    {
        gl::bindStockShader(gl::ShaderDef().color());
        // Draw the selection rect
        gl::color(ColorAf(1,1,0,0.5));
        gl::drawSolidRect(mDrawingRect);
    }
    
    if (mPopulation.getPopulation().size() > 0)
    {
        // Multiply
        glBlendFunc(GL_DST_COLOR, GL_ONE_MINUS_SRC_ALPHA);
        
        // Draw the current fittest
        gl::bindStockShader(gl::ShaderDef().color());
        gl::color(ColorAf(1,0,0,0.5));
        gl::setDefaultShaderVars();
        
        gl::pushMatrices();
        //gl::translate(mDrawingRect.getUpperLeft());
        GeneticFont & f = mPopulation.getFittestMember();
        f.render();
        gl::popMatrices();
        
        gl::enableAlphaBlending();
        gl::color(ColorAf(1,1,1,1));
        gl::pushMatrices();
        gl::translate(Vec2f(0,300));
        
        /*
        long fitness = f.getCalculatedFitness();
        if (fitness > -100)
        {
            mShouldAdvance = false;
        }
        */
        
        // Draw the fitness score
        Surface score = renderString("Fitness:" + to_string(f.getCalculatedFitness()),
                                     Font("Helvetica", 12),
                                     ColorAf(0,0,0,1));
        gl::TextureRef fitnessTex = gl::Texture::create(score);
        Vec2f texSize = fitnessTex->getSize();
        gl::draw(fitnessTex, Rectf(500,
                                   30,
                                   500 + texSize.x,
                                   30 + texSize.y));
        
        Surface fontName = renderString(f.getFontName(),
                                        Font("Helvetica", 12),
                                        ColorAf(0,0,0,1));
        gl::TextureRef nameTex = gl::Texture::create(fontName);
        texSize = nameTex->getSize();
        gl::draw(nameTex, Rectf(500,
                                   50,
                                   500 + texSize.x,
                                   50 + texSize.y));

        Surface fontSize = renderString(std::to_string(f.getFontSize()),
                                        Font("Helvetica", 12),
                                        ColorAf(0,0,0,1));
        gl::TextureRef sizeTex = gl::Texture::create(fontSize);
        texSize = sizeTex->getSize();
        gl::draw(sizeTex, Rectf(500,
                                   70,
                                   500 + texSize.x,
                                   70 + texSize.y));
        /*
        Surface fontPos = renderString(std::to_string(f.getPosition().x) + "," + std::to_string(f.getPosition().y),
                                        Font("Helvetica", 12),
                                        ColorAf(0,0,0,1));
        gl::TextureRef posTex = gl::Texture::create(fontPos);
        texSize = posTex->getSize();
        gl::draw(posTex, Rectf(500,
                                90,
                                500 + texSize.x,
                                90 + texSize.y));
        */
        Surface mutRate = renderString("Mutation: " + std::to_string(gMutationRate),
                                       Font("Helvetica", 12),
                                       ColorAf(0,0,0,1));
        gl::TextureRef mutTex = gl::Texture::create(mutRate);
        texSize = mutTex->getSize();
        gl::draw(mutTex, Rectf(500,
                               110,
                               500 + texSize.x,
                               110 + texSize.y));

        gl::popMatrices();
    }
}

CINDER_APP_NATIVE( BestFontCVApp, RendererGl )
