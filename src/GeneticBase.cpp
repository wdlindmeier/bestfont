//
//  GeneticBase.cpp
//  BestFontCV
//
//  Created by William Lindmeier on 11/18/13.
//
//

#include "GeneticBase.h"
#include "GeneUtilities.hpp"

// Crossover
GeneticBase::GeneticBase(const GeneticBase & gA, const GeneticBase & gB)
{
    std::vector<float> aGenes = gA.getGenes();
    std::vector<float> bGenes = gB.getGenes();
    
    assert(aGenes.size() == bGenes.size());
    mNumGenes = aGenes.size();

    // Randomly pick genese from the mother or father
    mDNA.clear();
    for (int i = 0; i < mNumGenes; ++i)
    {
        float randGene = RandBool() ? aGenes[i] : bGenes[i];
        mDNA.push_back(randGene);
    }
    
    mutate();
    
    expressGenes();
}

GeneticBase::GeneticBase(const int numGenes)
{
    mNumGenes = numGenes;

    randomizeDNA();
    
    // NOTE: We don't have to mutate if the values are all random
    // mutate();
    expressGenes();
}

std::vector<float> GeneticBase::getGenes() const
{
    return mDNA;
}

void GeneticBase::randomizeDNA()
{
    mDNA.clear();
    for (int i = 0; i < mNumGenes; ++i)
    {
        mDNA.push_back(RandScalar());
    }
}

void GeneticBase::mutate()
{
    std::vector<float> mDNA;
    for (int i = 0; i < mDNA.size(); ++i)
    {
        if (ShouldMutate())
        {
            mDNA[i] = RandScalar();
        }
    }
}

void GeneticBase::expressGenes()
{
    // Does nothing. Call express genes again from the Subclass
}