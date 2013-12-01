//
//  GeneticFont.cpp
//  BestFontCV
//
//  Created by William Lindmeier on 11/18/13.
//
//

#include "GeneticFont.h"
#include "GeneUtilities.hpp"
#include "cinder/Surface.h"
#include "cinder/Text.h"
#include "GeneticConstraints.hpp"

using namespace std;
using namespace ci;
using namespace ci::gl;

// Decides if the app should try to match the text content as well
#define USE_OCR 0

const static char AvailableCharCount = 63;
const static char AvailableChars[AvailableCharCount] = {'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z', 'a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z', ' ', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9'};

// NOTE: How can this elegantly track the amount of genes we actually use/need?
#if USE_OCR
const static int kNumFontGenes = 23;
#else 
const static int kNumFontGenes = 2; // Wow, this is tiny
#endif

GeneticFont::GeneticFont() : GeneticBase(kNumFontGenes)
{
    if (gDisplayString == "")
    {
        ci::app::console() << "Ignoring font. Display string is empty.\n";
        return;
    }
    
    // Get the global display string. What's a better pattern w/out using a global?
    setDisplayText(gDisplayString);
    
    // Get the display text from a global.
    // It aint pretty, but I'm not sure what the best generic pattern would be.
    expressGenes();
}

GeneticFont::GeneticFont(const GeneticFont & gA, const GeneticFont & gB) :
GeneticBase(gA, gB)
{
    if (gDisplayString == "")
    {
        ci::app::console() << "Ignoring font. Display string is empty.\n";
        return;
    }

    // Get the global display string. What's a better pattern w/out using a global?
    setDisplayText(gDisplayString);
    
    // Let the super handle the crossover.
    // Just swapping numbers.
    expressGenes();
};

std::string GeneticFont::getDisplayText() const
{
    return mDisplayText;
}

void GeneticFont::setDisplayText(const std::string & text)
{
    mDisplayText = text;
}

void GeneticFont::expressGenes()
{
    GeneticConstraintsRef constraints = GeneticConstraints::getSharedConstraints();
    
    // Convert dna into attributes

    // NOTE: These values are constrained to ranges... is there a better way to do this?
    // Maybe the DNA isn't a scalar, but rather open ended.

    int geneNum = 0;
    
    // Font size
    float fontSizeGene = mDNA[geneNum++];
    mFontSize = 1.0f + (fontSizeGene * constraints->maxFontSize);
    
    // Pick the font
    float fontGene = mDNA[geneNum++];
    NSArray *allFonts = [[NSFontManager sharedFontManager] availableFonts];
    int numFonts = allFonts.count;
    float fontInterval = 1.0f / numFonts;
    int pickFont = fontGene / fontInterval;
    NSString *nsFontName = [allFonts objectAtIndex:pickFont];
    mFontName = string([nsFontName UTF8String]);
    mFont = Font(mFontName, mFontSize);

#if USE_OCR
    // Display text
    float fontNumChars = mDNA[geneNum++];
    mNumChars = (int)(fontNumChars * constraints->maxCharacters) + 1;
    mDisplayText = "";
    for (int i = 0; i < constraints->maxCharacters; ++i)
    {
        float charGene = mDNA[geneNum++];
        if (i < mNumChars)
        {
            int charIdx = (int)(charGene * AvailableCharCount);
            mDisplayText += AvailableChars[charIdx];
        }
        // Don't break. We want all of the char genes to get used.
    }
#endif

    // Generate the image
    Surface8u textSurf = ci::renderString(mDisplayText, mFont, Color(0,0,0));
    // Using the alpha channel to compare because renderString draws on a transparent background.
    mChannel = textSurf.getChannelAlpha().clone();
    
    // Invert the channel for more intuitive comparison & drawing
    Channel::Iter iter = mChannel.getIter(Area(0,0,textSurf.getWidth(),textSurf.getHeight()));
    int minX = 16000;
    int minY = 16000;
    int maxX = 0;
    int maxY = 0;
    while( iter.line() )
    {
        while( iter.pixel() )
        {
            int invertedVal = 255 - iter.v();
            if (invertedVal < kPxWhitness)
            {
                // This is a pixel
                if (iter.x() < minX) minX = iter.x();
                if (iter.x() > maxX) maxX = iter.x();
                if (iter.y() < minY) minY = iter.y();
                if (iter.y() > maxY) maxY = iter.y();
            }
            iter.v() = invertedVal;
        }
    }
    if (minX < maxX && minY < maxY)
    {
        int width = maxX - minX;
        int height = maxY - minY;
        Channel8u croppedChannel(width, height);
        croppedChannel.copyFrom(mChannel,
                                Area(Vec2i(minX, minY), Vec2i(maxX, maxY)),
                                Vec2i(-minX, -minY));
        mChannel = croppedChannel;
    }

    // Verify that the gene count is accurate
    assert(geneNum == kNumFontGenes);
}

double GeneticFont::calculateFitnessScalar(const ci::Channel8u & compareChan)
{
    Vec2i mySize = mChannel.getSize();
    Vec2i targetSize = compareChan.getSize();
    
    // Give value for being the same size.
    mFitness = (abs(targetSize.x - mySize.x) + abs(targetSize.y - mySize.y)) * -1;

    long totalScore = 0;
    //long numSamplePx = 0;
    //long numTargetPx = 0;
    
    // Iterate over self.
    // Compare pixels.
    for (int x = 0; x < mySize.x; ++x)
    {
        for (int y = 0; y < mySize.y; ++y)
        {
            Vec2i selfPx(x, y);
            Vec2i targetPx(x, y);
            
            int selfVal = mChannel.getValue(selfPx);
            BOOL selfIsBlack = selfVal < kPxWhitness;
            
            /*
            if (selfIsBlack)
            {
                numSamplePx += 1;
            }
            */
            
            // Check if there's a sample
            if (targetPx.x >= 0 &&
                targetPx.y >= 0 &&
                targetSize.x > targetPx.x &&
                targetSize.y > targetPx.y)
            {
                // There IS a sample.
                // Check value
                int targetVal = compareChan.getValue(targetPx);
                BOOL targetIsBlack = targetVal < kPxWhitness;

                if (targetIsBlack == selfIsBlack)
                {
                    // Add score if there's a pixel match
                    totalScore += 1;
                }
                else
                {
                    // Subtract score of they aren't the same
                    totalScore -= 1;
                }
            }
            else
            {
                // Outside of bounds
                // This should be accounted for in the size weight above.
                // totalScore -= 1;
            }
        }
    }
    /*
    // Just counting pixels
    for (int x = 0; x < targetSize.x; ++x)
    {
        for (int y = 0; y < targetSize.y; ++y)
        {
            Vec2i targetPx(x,y);
            int targetVal = compareChan.getValue(targetPx);

            BOOL targetIsPx = targetVal < kPxWhitness;
            if (targetIsPx)
            {
                numTargetPx += 1;
            }
            // Not adding or subtracting score: That should be accounted for in the size weight.
        }
    }
    */
    mFitness += totalScore;
    
    // Make it scalar.
    // This prevents giving small candidates an advantage.
    mFitness = (double)mFitness / (double)(mySize.x * mySize.y);
    
    return mFitness;
}

std::string GeneticFont::getFontName()
{
    return mFontName;
}

float GeneticFont::getFontSize()
{
    return mFontSize;
}

double GeneticFont::calculateFitnessScalar()
{
    ci::app::console() << "ERROR: Use calculateFitnessScalar(const cv::Mat & compareMat)" << std::endl;
    throw std::exception();
}

double GeneticFont::getCalculatedFitness()
{
    return mFitness;
}

void GeneticFont::render()
{
    gl::TextureRef texture = gl::Texture::create(mChannel);
    gl::draw(texture);
}
