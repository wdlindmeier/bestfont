//
//  GeneticPopulation.h
//  BestFontCV
//
//  Created by William Lindmeier on 11/24/13.
//
//

#pragma once
#include "cinder/CinderMath.h"
#include "cinder/Utilities.h"

template <class T>
class GeneticPopulation
{

public:
    
    GeneticPopulation(const int initialPopulationSize) :
    mPopulationSize(initialPopulationSize)
    ,mGenerationCount(0)
    {
        initializeRandomPopulation();
    }
    
    ~GeneticPopulation(){};
    
    std::vector<T> & getPopulation()
    {
        return mPopulation;
    }
    
    // NOTE: This is the fittest member from the LAST RUN generation,
    // since fitness is calculated immediately before a new generation
    // has been created.
    T & getFittestMember()
    {
        return mFittestMember;
    }
    
    long getGenerationCount()
    {
        return mGenerationCount;
    }
    
    void runGeneration(std::function<float (T & member)> fitnessEvaluation)
    {
        float minFitness = 1.f;
        float maxFitness = 0.f;
        mGenerationCount++;

        // Generate fitness scores
        std::vector<float> memberFitnesses;
        for (T & m : mPopulation)
        {
            float memberFitness = fitnessEvaluation(m);
            memberFitnesses.push_back(memberFitness);
            if (memberFitness < minFitness)
            {
                minFitness = memberFitness;
            }
            if (memberFitness > maxFitness)
            {
                maxFitness = memberFitness;
                mFittestMember = m;
            }
        }
        
        if (minFitness == maxFitness)
        {
            // This would give us a pool size of 1.
            // Expand the range so the single winner has a chance to reproduce.
            minFitness -= 0.5;
            maxFitness += 0.5;
        }
        
        // Create the mating pool
        std::vector<T> matingPool;
        for (int i = 0; i < memberFitnesses.size(); ++i)
        {
            float fitness = memberFitnesses[i];
            // NOTE: max possible reproduction count is the same as the population size.
            int mappedFitness = ci::lmap<float>(fitness, minFitness, maxFitness, 1, mPopulationSize);
            // Add to the pool N times
            for (int j = 0; j < mappedFitness; ++j)
            {
                matingPool.push_back(mPopulation[i]);
            }
        }
        
        // Check the pool size
        int poolSize = matingPool.size();
        if (poolSize < 1)
        {
            ci::app::console() << "ERROR: Population has a size of 0. Aborting generation.\n";
            return;
        }
        
        // Create a new generation
        std::vector<T> newGeneration;
        for (int i = 0; i < mPopulationSize; ++i)
        {
            // Pick a mate (This CAN include yourself. Thanks mutation!)
            int mateA = arc4random() % poolSize;
            int mateB = arc4random() % poolSize;

            // Crossover
            T child = T(matingPool[mateA], matingPool[mateB]);
            
            // NOTE: Mutation and expression are handled in the constructors
            
            // Add to the population
            newGeneration.push_back(child);
        }
        
        // Et voila!
        mPopulation = newGeneration;
    }

private:
    
    void initializeRandomPopulation()
    {
        mPopulation.clear();
        for (int i = 0; i < mPopulationSize; ++i)
        {
            mPopulation.push_back(T());
        }
    }

    int mPopulationSize;
    std::vector<T> mPopulation;
    T mFittestMember;
    long mGenerationCount;
    
};