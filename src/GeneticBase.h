//
//  GeneticBase.h
//  BestFontCV
//
//  Created by William Lindmeier on 11/18/13.
//
//

#pragma once

class GeneticBase
{
    
public:
    
    // Default constructor returns a random gene sequence.
    GeneticBase(const int numGenes);
    // Crossover
    GeneticBase(const GeneticBase & gA, const GeneticBase & gB);
    virtual ~GeneticBase(){};

    // Expression must be handled in subclases.
    virtual void expressGenes();
    virtual float calculateFitnessScalar() = 0;
    
    std::vector<float> getGenes() const;
    
protected:
    
    void randomizeDNA();
    void mutate();
    
    int mNumGenes;
    std::vector<float> mDNA;
    
};
