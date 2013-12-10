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

extern float gMutationRate = 0.085;
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
    void            finishTextSelection();
    void            keyUp(KeyEvent event);
    void            update();
    std::string     getImageText();
    int             displayInstructions();
    void            restartPopulation();
    void            pickFile();
    void            drawMetadata(const Vec2f & offset);
	
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
    
    gl::TextureRef  mButtonTexture;
    
    bool            mDidPickFile;
    bool            mDidDrawImage;

};

void BestFontCVApp::prepareSettings(Settings *settings)
{
    settings->setWindowSize(800, 600);
    settings->setWindowPos(100, 100);
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
    mMousePositionStart = Vec2f(-1,-1);
    mShouldAdvance = false;
    gMutationRate = 0.085f;
    mButtonTexture = gl::Texture::create(loadImage(getResourcePath("button_pick.png")));
    mDidPickFile = false;
    mDidDrawImage = false;
}

void BestFontCVApp::pickFile()
{
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
    
    float sliderY = (getWindowHeight() * 0.5) + 10;
    mSliderMutation = Slider(Rectf(10, sliderY, 200, sliderY + 20));
    mSliderMutation.setValue(0.5f);
    mDidPickFile = true;
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
    
    if (!mDidPickFile)
    {
        pickFile();
        return;
    }
    
    if (mMousePosition.y < getWindowHeight() * 0.5)
    {
        // Top half: text selection
        mMousePositionStart = mMousePosition;
        mDrawingRect = Rectf(mMousePosition.x, mMousePosition.y,
                             mMousePosition.x, mMousePosition.y);

    }
    else
    {
        // Bottom half: slider
        mMousePositionStart = Vec2f(-1,-1);
        mSliderMutation.setIsActive(mSliderMutation.contains(mMousePosition));
        if (mSliderMutation.getIsActive())
        {
            updateMutationSliderWithMousePos(mMousePosition);
            return;
        }
    }
}

void BestFontCVApp::mouseDrag(MouseEvent event)
{
    mMousePosition = event.getPos();
    
    if (mMousePosition.y < getWindowHeight() * 0.5)
    {
        // Top half: text selection
        if (mMousePositionStart.x >= 0)
        {
            mDrawingRect = rectFromTwoPos(mMousePosition, mMousePositionStart);
            mMousePositionEnd = mMousePosition;
        }
    }
    else if (mSliderMutation.getIsActive())
    {
        // Bottom half: slider
        updateMutationSliderWithMousePos(mMousePosition);
    }
}

void BestFontCVApp::mouseUp(MouseEvent event)
{
    if (mMousePosition.y >= getWindowHeight() * 0.5)
    {
        // Bottom half: slider
        if (mSliderMutation.getIsActive())
        {
            mSliderMutation.setValue(0.5f);
            mSliderMutation.setIsActive(false);
        }
    }
    else
    {
        if (mMousePositionStart.x > 0)
        {
            finishTextSelection();
        }
    }
    
    mMousePositionStart = Vec2f(-1,-1);
}

#pragma mark - Text Selection

void BestFontCVApp::finishTextSelection()
{
    // Top half: selection
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
        int width = (maxX - minX) + 1;
        int height = (maxY - minY) + 1;
        Channel8u croppedChannel(width, height);
        croppedChannel.copyFrom(mTargetSelectionChan,
                                Area(Vec2i(minX, minY), Vec2i(maxX + 1, maxY + 1)),
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
            // Evolution:
            const static int kNumBatchesPerGeneration = 6;
            mPopulation.runGenerationBatch(kNumBatchesPerGeneration, [&](GeneticFont & font)// -> float
                                           {
                                               // Passes the image into the font for comparison
                                               return font.calculateFitnessScalar(mTargetSelectionChan);
                                           });
        }
    }
    
    // Waiting to prompt user until the image has been drawn so they can reference it.
    if (mDidPickFile && mDidDrawImage && gDisplayString == "")
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
    gl::clear(Color( 1, 1, 1 ));
    gl::color(ColorAf(1,1,1,1));
    
    // Draw the button if we haven't picked a file
    if (!mDidPickFile)
    {
        Vec2f buttonSize = mButtonTexture->getSize();
        
        Vec2f buttonPos((getWindowWidth() * 0.5) - (buttonSize.x * 0.5),
                        (getWindowHeight() * 0.5) - (buttonSize.y * 0.5));
        
        gl::draw(mButtonTexture, Rectf(buttonPos.x,
                                       buttonPos.y,
                                       buttonPos.x + buttonSize.x,
                                       buttonPos.y + buttonSize.y));
        return;
    }
    
    // Draw the selected image
    mDidDrawImage = true;

    gl::draw(mTargetTexture, Rectf(mTargetOffsetTop.x,
                                   mTargetOffsetTop.y,
                                   mTargetOffsetTop.x + mTargetTexture->getWidth(),
                                   mTargetOffsetTop.y + mTargetTexture->getHeight()));
    
    float halfHeight = getWindowHeight() * 0.5;
    Rectf maskRect = mDrawingRect;
    maskRect.y1 += halfHeight;
    maskRect.y2 += halfHeight;

    gl::bindStockShader(gl::ShaderDef().color());

    Vec2f metaOffset(600, (getWindowHeight() * 0.5f) + 15);
    
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
    
        // Draw the metadata
        if (mPopulation.getPopulation().size() > 0)
        {
            drawMetadata(metaOffset);
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
                           metaOffset.y,
                           250 + texSize.x,
                           metaOffset.y + texSize.y));
}

void BestFontCVApp::drawMetadata(const Vec2f & offset)
{
    gl::color(ColorAf(1,1,1,1));
    
    gl::pushMatrices();
    GeneticFont & f = mPopulation.getFittestMember();
    // Draw it over the mask
    gl::translate(mDrawFittestOffset);
    f.render();
    gl::popMatrices();
    
    gl::enableAlphaBlending();
    
    gl::pushMatrices();
    gl::translate(offset);
    
    const float kLineHeight = 20;
    float yOff = 0;
    
    // This is an annoying side-effect of using cinder dev.
    // gl::drawString is not-yet implemented.
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

CINDER_APP_NATIVE( BestFontCVApp, RendererGl )
