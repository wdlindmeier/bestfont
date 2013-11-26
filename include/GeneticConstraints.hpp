//
//  GeneticConstraints.hpp
//  BestFontCV
//
//  Created by William Lindmeier on 11/26/13.
//
//

#pragma once

// A container for shared genetic constraints.
// Using a singleton pattern.

class GeneticConstraints;

typedef std::shared_ptr<GeneticConstraints> GeneticConstraintsRef;

class GeneticConstraints
{
    
public:
    
    GeneticConstraints() :
    maxPosX(0.f)
    ,maxPosY(0.f)
    ,maxFontSize(150.f)
    {};
    ~GeneticConstraints(){};
    
    float maxPosX;
    float maxPosY;
    float maxFontSize;
    
    // Singleton
    static GeneticConstraintsRef getSharedConstraints()
    {
        static GeneticConstraintsRef sharedConstraints;
        if (!sharedConstraints)
        {
            sharedConstraints = GeneticConstraintsRef(new GeneticConstraints());
        }
        return sharedConstraints;
    }
};