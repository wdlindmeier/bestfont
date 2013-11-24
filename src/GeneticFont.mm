//
//  GeneticFont.cpp
//  BestFontCV
//
//  Created by William Lindmeier on 11/18/13.
//
//

#include "GeneticFont.h"
#include "GeneUtilities.hpp"
#include "cinder/Text.h"

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
    // Convert dna into attributes

    // NOTE: These values are constrained to ranges... is there a better way to do this?
    // Maybe the DNA isn't a scalar, but rather open ended.

    int geneNum = 0;
    
    // Font size
    float fontSizeGene = mDNA[geneNum++];
    mFontSize = 1.0f + (fontSizeGene * kMaxFontSize);
    
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
    mPosition = ci::Vec2f(kMaxFontX * posXGene, kMaxFontY * posYGene);
    
    // Display text
    // TMP: Just hard-coding it for now
    mDisplayText = "GALLAGHER";

    // Generate the image
    mFrameSurf = ci::renderString(mDisplayText, mFont, Color(0,0,0));

    // Verify that the gene count is accurate
    assert(geneNum == kNumFontGenes);
}

float GeneticFont::calculateFitnessScalar(const ci::Surface8u & compareSurf)
{
    // For now just hard-code the color.
    return RandScalar();
}

float GeneticFont::calculateFitnessScalar()
{
    ci::app::console() << "ERROR: Use calculateFitnessScalar(const cv::Mat & compareMat)" << std::endl;
    throw std::exception();
}

void GeneticFont::render()
{
    gl::TextureRef texture = gl::Texture::create(mFrameSurf);

    gl::pushMatrices();
    gl::translate(mPosition);
    gl::draw(texture);
    gl::popMatrices();
}
