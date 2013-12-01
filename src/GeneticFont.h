//
//  GeneticFont.h
//  BestFontCV
//
//  Created by William Lindmeier on 11/18/13.
//
//

#pragma once

#include "cinder/Font.h"
#include "cinder/gl/gl.h"
#include "cinder/gl/Texture.h"
#include "cinder/Surface.h"
#include "cinder/Channel.h"
#include "CinderOpenCv.h"
#include "BestFontConstants.h"
#include "GeneticBase.h"

class GeneticFont : public GeneticBase
{

public:
    
    GeneticFont();
    GeneticFont(const GeneticFont & gA, const GeneticFont & gB);
    virtual ~GeneticFont(){}
    
    virtual void expressGenes();
    double calculateFitnessScalar(const ci::Channel8u & compareChan);
    double getCalculatedFitness();
    void render();
    // Don't use this:
    double calculateFitnessScalar();
    
    std::string getFontName();
    std::string getDisplayText() const;
    void setDisplayText(const std::string & text);
    float getFontSize();

protected:

    ci::Channel8u       mChannel;
    ci::Font            mFont;
    float               mFontSize;
    std::string         mFontName;
    std::string         mDisplayText;
    double              mFitness;
    int                 mNumChars;
    
};