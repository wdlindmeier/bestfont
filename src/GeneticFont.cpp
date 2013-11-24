//
//  GeneticFont.cpp
//  BestFontCV
//
//  Created by William Lindmeier on 11/18/13.
//
//

#include "GeneticFont.h"
#include "GeneUtilities.hpp"

GeneticFont::GeneticFont(const GeneticFont & gA, const GeneticFont & gB) :
GeneticBase(gA, gB)
{
    // Let the super handle the crossover.
    // Just swapping numbers.
};

void GeneticFont::expressGenes()
{
    // Convert dna into attributes
    /*
    ci::Font            mFont;
    float               mFontSize;
    std::string         mFontName;
    ci::Vec2f           mPosition;
    cv::Mat             mMat;
    */
}

float GeneticFont::calculateFitnessScalar(const cv::Mat & compareMat)
{
    return RandScalar();
}

float GeneticFont::calculateFitnessScalar()
{
    ci::app::console() << "ERROR: Use calculateFitnessScalar(const cv::Mat & compareMat)" << std::endl;
    throw std::exception();
}
