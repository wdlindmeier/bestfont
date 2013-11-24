//
//  GeneticFont.h
//  BestFontCV
//
//  Created by William Lindmeier on 11/18/13.
//
//

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

#pragma once

#include "GeneticBase.h"

const static int kNumFontGenes = 20;

class GeneticFont : public GeneticBase
{

public:
    
    GeneticFont() : GeneticBase(kNumFontGenes){}
    GeneticFont(const GeneticFont & gA, const GeneticFont & gB);
    virtual ~GeneticFont(){}
    
    void expressGenes();
    float calculateFitnessScalar(const cv::Mat & compareMat);
    // Don't use this:
    float calculateFitnessScalar();

protected:
    
    ci::gl::TextureRef  mTexture;
    ci::Font            mFont;
    float               mFontSize;
    std::string         mFontName;
    ci::Vec2f           mPosition;
    cv::Mat             mMat;

};