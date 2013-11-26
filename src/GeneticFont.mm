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

// NOTE: How can this elegantly track the amount of genes we actually use/need?
const static int kNumFontGenes = 4;

GeneticFont::GeneticFont() : GeneticBase(kNumFontGenes)
{
    expressGenes();
}

GeneticFont::GeneticFont(const GeneticFont & gA, const GeneticFont & gB) :
GeneticBase(gA, gB)
{
    // Let the super handle the crossover.
    // Just swapping numbers.
    expressGenes();
};

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

    // Position
    float posXGene = mDNA[geneNum++];
    float posYGene = mDNA[geneNum++];
    // Allowing negative positioning
    mPosition = ci::Vec2f(((constraints->maxPosX * 2) * posXGene) - constraints->maxPosX,
                          ((constraints->maxPosY * 2) * posYGene) - constraints->maxPosY);
    
    // Display text
    // TMP: Just hard-coding it for now
    mDisplayText = "GALLAGHER";

    // Generate the image
    Surface8u textSurf = ci::renderString(mDisplayText, mFont, Color(0,0,0));
    // Using the alpha channel to compare because renderString draws on a transparent background.
    mChannel = textSurf.getChannelAlpha().clone();
    
    // Invert the channel for more intuitive comparison & drawing
    Channel::Iter iter = mChannel.getIter(Area(0,0,textSurf.getWidth(),textSurf.getHeight()));
    while( iter.line() ) {
        while( iter.pixel() ) {
            iter.v() = 255 - iter.v();
        }
    }

    // Verify that the gene count is accurate
    assert(geneNum == kNumFontGenes);
}

double GeneticFont::calculateFitnessScalar(const ci::Channel8u & compareChan)
{
    // return RandScalar();
    
    Vec2i mySize = mChannel.getSize();
    Vec2i targetSize = compareChan.getSize();
    
    /*
    long maxX = std::max<int>(mySize.x,targetSize.x);
    long maxY = std::max<int>(mySize.y,targetSize.y);
    long bestScore = maxX * maxY;
    */
    
    long totalScore = 0;

    const static int kPxWhitness = 100;
    
    // Iterate over self
    for (int x = 0; x < mySize.x; ++x)
    {
        for (int y = 0; y < mySize.y; ++y)
        {
            Vec2i selfPx(x, y);
            Vec2i targetPx(mPosition.x + x, mPosition.y + y);
            
            int selfVal = mChannel.getValue(selfPx);
            BOOL selfIsBlack = selfVal < kPxWhitness;
            
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

                if ((targetIsBlack && selfIsBlack) ||
                    (!targetIsBlack && !selfIsBlack))
                {
                    // Add score
                    totalScore += 1;
                }
                else
                {
                    // Subtract score
                    totalScore -= 1;
                }
            }
            else
            {
                // This is a px
                // Only subtract if the out-of-bounds px is dark.
                // It's OK to have whitespace hanging out.
                if (selfIsBlack)
                {
                    // Outside of bounds
                    // Subtract 2 from score
                    totalScore -= 2;
                }
            }
        }
    }
    
    // NEXT: Iterate over the target and subtract score for any positive pixels that
    // exist in the target but not the self
    for (int x = 0; x < targetSize.x; ++x)
    {
        for (int y = 0; y < targetSize.y; ++y)
        {
            Vec2i targetPx(x,y);
            int targetVal = compareChan.getValue(targetPx);
            // Ignore white pixels
            if (targetVal < kPxWhitness)
            {
                if (x < mPosition.x ||
                    y < mPosition.y ||
                    x > (mPosition.x + mySize.x) ||
                    y > (mPosition.y + mySize.y))
                {
                    // This is a positive pixel and it's outside of the range
                    // of the sample. Subtract 2 from score.
                    totalScore -= 2;
                }
            }
        }
    }
    
    mFitness = totalScore;//(double)totalScore / (double)bestScore;
    // ci::app::console() << mFitness << ",";
    
    /*
    int sampleWidth = std::min<int>(compareChan.getWidth() - mPosition.x,
                                    mySize.x);
    int sampleHeight = std::min<int>(compareChan.getHeight() - mPosition.y,
                                     mySize.y);
    
    long numSamplePx = sampleWidth * sampleHeight;
    long numSelfPx = mySize.x * mySize.y;

    // maxDelta is the theoretically inverted image
    long maxDelta = 255 * numSamplePx;
    long sampleDelta = 0;
    
    //if (numSelfPx != numSamplePx)
    {
        // Also subtract values for any pixels that over/under lap
        
        // TODO: This should ONLY penalize underlapping pixels that
        // ignore actual text pixels.
        // (i.e.) There should be no penalty for the user over selecting the bounds.
        
        long unsampledDelta = 255 * abs(numSelfPx - numSamplePx);
        maxDelta += unsampledDelta;
        sampleDelta += unsampledDelta;
    }

    // Sample the overlapping pixels
    for (int x = 0; x < sampleWidth; ++x)
    {
        for (int y = 0; y < sampleHeight; ++y)
        {
            // IMPORTANT: Add the offset to the compareSurf sample point.
            Vec2i targetPx(mPosition.x + x, mPosition.y + y);
            Vec2i selfPx(x, y);
            
            int targetVal = compareChan.getValue(targetPx);
            int selfVal = mChannel.getValue(selfPx);
            int pxDelta = abs(targetVal - selfVal);
            sampleDelta += pxDelta;
        }
    }
    
    float scalarDifference = (double)sampleDelta / (double)maxDelta;
    
    mFitness = 1.0f - scalarDifference;
    */
    
    // ci::app::console() << mFitness << ", ";

    return mFitness;
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

    gl::pushMatrices();
    gl::translate(mPosition);
    gl::draw(texture);
    gl::popMatrices();
}
