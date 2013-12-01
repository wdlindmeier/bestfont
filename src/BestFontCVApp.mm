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
#include "Slider.hpp"

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
    void            updateMutationSliderWithMousePos( Vec2i & mousePos );
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
    
    Vec2i           mTargetOffsetTop;
    Vec2i           mTargetOffsetBottom;
    
    GeneticPopulation<GeneticFont> mPopulation;
    
    bool            mShouldAdvance;
    Vec2f           mDrawFittestOffset;
    
    Slider          mSliderMutation;

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
    
    float halfHeight = getWindowHeight() * 0.5;
    mTargetOffsetTop = Vec2i((getWindowWidth() - mTargetSurface.getWidth()) * 0.5,
                             (halfHeight - mTargetSurface.getHeight()) * 0.5);
    mTargetOffsetBottom = mTargetOffsetTop + Vec2f(0, halfHeight);
    
    mSliderMutation = Slider(Rectf(10, 10, 200, 30));
    mSliderMutation.setValue(0.5f);

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

const static float kMutationSliderMagnitude = 0.01f;

void BestFontCVApp::updateMutationSliderWithMousePos( Vec2i & mousePos )
{
    mSliderMutation.update(mousePos);
    float mutationDelta = (mSliderMutation.getValue() - 0.5f) * kMutationSliderMagnitude;
    gMutationRate = std::max<float>(0, gMutationRate + mutationDelta);
}

void BestFontCVApp::mouseDown( MouseEvent event )
{
    mMousePosition = event.getPos();
    mSliderMutation.setIsActive(mSliderMutation.contains(mMousePosition));

    if (mSliderMutation.getIsActive())
    {
        updateMutationSliderWithMousePos(mMousePosition);
        return;
    }
    // else
    mMousePositionStart = mMousePosition;
    mDrawingRect = Rectf(mMousePosition.x, mMousePosition.y,
                         mMousePosition.x, mMousePosition.y);
}

void BestFontCVApp::mouseDrag(MouseEvent event)
{
    mMousePosition = event.getPos();
    if (mSliderMutation.getIsActive())
    {
        updateMutationSliderWithMousePos(mMousePosition);
        return;
    }
    // else
    mDrawingRect = rectFromTwoPos(mMousePosition, mMousePositionStart);
    mMousePositionEnd = mMousePosition;
}

void BestFontCVApp::mouseUp(MouseEvent event)
{
    if (mSliderMutation.getIsActive())
    {
        mSliderMutation.setValue(0.5f);
        mSliderMutation.setIsActive(false);
        return;
    }
    // else
    cv::Mat targetMat = toOcv(mTargetSurface);
    cv::Size inputSize = targetMat.size();
    float x = ci::math<float>::clamp(mDrawingRect.x1 - mTargetOffsetTop.x, 0, inputSize.width);
    float y = ci::math<float>::clamp(mDrawingRect.y1 - mTargetOffsetTop.y, 0, inputSize.height);
    float w = ci::math<float>::clamp(mDrawingRect.getWidth(), 0, inputSize.width - x);
    float h = ci::math<float>::clamp(mDrawingRect.getHeight(), 0, inputSize.height - y);
    if (w <= 0 || h <= 0)
    {
        // Abort selectionx
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
    
    float halfHeight = getWindowHeight() * 0.5f;
    mDrawFittestOffset = mDrawingRect.getUpperLeft() + Vec2f(minX, minY + halfHeight);
    
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
    if (mSliderMutation.getIsActive())
    {
        updateMutationSliderWithMousePos(mMousePosition);
    }

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

    /*
    if (mDrawingRect.getWidth() > 0)
    {
        // Draw the current selection
        gl::color(ColorAf(0,1,1,0.5));
        gl::draw(mTargetSelectionTex);
    }
    */
    
    gl::color(ColorAf(1,1,1,1));
    gl::draw(mTargetTexture, Rectf(mTargetOffsetTop.x,
                                   mTargetOffsetTop.y,
                                   mTargetOffsetTop.x + mTargetTexture->getWidth(),
                                   mTargetOffsetTop.y + mTargetTexture->getHeight()));

    
    float halfHeight = getWindowHeight() * 0.5;
    Rectf maskRect = mDrawingRect;
    maskRect.y1 += halfHeight;
    maskRect.y2 += halfHeight;

    gl::bindStockShader(gl::ShaderDef().color());

    if (mDrawingRect.getWidth() > 0)
    {
        gl::draw(mTargetTexture, Rectf(mTargetOffsetBottom.x,
                                       mTargetOffsetBottom.y,
                                       mTargetOffsetBottom.x + mTargetTexture->getWidth(),
                                       mTargetOffsetBottom.y + mTargetTexture->getHeight()));
        // Draw the mask
        gl::disableAlphaBlending();
        gl::color(1,1,1,1);
        gl::drawSolidRect(maskRect);
        gl::enableAlphaBlending();

        // Draw the selection rect
        gl::color(ColorAf(1,1,0,0.5));
        gl::drawSolidRect(mDrawingRect);
    
        if (mPopulation.getPopulation().size() > 0)
        {
            // gl::setDefaultShaderVars();
            gl::color(ColorAf(1,1,1,1));
            
            gl::pushMatrices();
            GeneticFont & f = mPopulation.getFittestMember();
            // Draw it over the mask
            gl::translate(mDrawFittestOffset);
            f.render();
            gl::popMatrices();
            
            gl::enableAlphaBlending();

            Vec2f outpOffset(600, 15);
            
            gl::pushMatrices();
            gl::translate(outpOffset);
            
            const float kLineHeight = 20;
            float yOff = 0;

            Surface genCount = renderString("Generation: " + std::to_string(mPopulation.getGenerationCount()),
                                            Font("Helvetica", 12),
                                            ColorAf(0,0,0,1));
            gl::TextureRef genTex = gl::Texture::create(genCount);
            Vec2f texSize = genTex->getSize();
            gl::draw(genTex, Rectf(0,
                                   yOff,
                                   texSize.x,
                                   yOff + texSize.y));

            yOff += kLineHeight;
            
            Surface score = renderString("Fitness: " + to_string(f.getCalculatedFitness()),
                                         Font("Helvetica", 12),
                                         ColorAf(0,0,0,1));
            gl::TextureRef fitnessTex = gl::Texture::create(score);
            texSize = fitnessTex->getSize();
            gl::draw(fitnessTex, Rectf(0,
                                       yOff,
                                       texSize.x,
                                       yOff + texSize.y));
            
            yOff += kLineHeight;
            
            Surface fontName = renderString(f.getFontName(),
                                            Font("Helvetica", 12),
                                            ColorAf(0,0,0,1));
            gl::TextureRef nameTex = gl::Texture::create(fontName);
            texSize = nameTex->getSize();
            gl::draw(nameTex, Rectf(0,
                                    yOff,
                                    texSize.x,
                                    yOff + texSize.y));

            yOff += kLineHeight;
            
            Surface fontSize = renderString("Font Size: " + std::to_string(f.getFontSize()),
                                            Font("Helvetica", 12),
                                            ColorAf(0,0,0,1));
            gl::TextureRef sizeTex = gl::Texture::create(fontSize);
            texSize = sizeTex->getSize();
            gl::draw(sizeTex, Rectf(0,
                                    yOff,
                                    texSize.x,
                                    yOff + texSize.y));
            gl::popMatrices();
        }
    }
    
    // Splitting line
    gl::color(Color(0.5,0.5,0.5));
    gl::drawSolidRect(Rectf(0,
                            halfHeight,
                            getWindowWidth(),
                            halfHeight + 1));
    
    // Render slider
    mSliderMutation.render(true);
    
    Surface mutRate = renderString("Mutation: " + std::to_string(gMutationRate),
                                   Font("Helvetica", 12),
                                   ColorAf(0,0,0,1));
    gl::TextureRef mutTex = gl::Texture::create(mutRate);
    Vec2f texSize = mutTex->getSize();
    gl::draw(mutTex, Rectf(250,
                           15,
                           250 + texSize.x,
                           15 + texSize.y));
    
    
}

CINDER_APP_NATIVE( BestFontCVApp, RendererGl )
