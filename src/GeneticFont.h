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
    float calculateFitnessScalar(const ci::Surface8u & compareSurf);
    // Don't use this:
    float calculateFitnessScalar();
    void render();

protected:
    
    ci::Surface8u       mFrameSurf;
    ci::Font            mFont;
    float               mFontSize;
    std::string         mFontName;
    std::string         mDisplayText;
    ci::Vec2f           mPosition;
    cv::Mat             mMat;

};