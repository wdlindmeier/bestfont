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
#include "BestFontConstants.h"

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
    
    void threadEval(const int memberIndex, std::function<float (T & member)> fitnessEvaluation, T & m)
    {
        mFitnessScores[memberIndex] = fitnessEvaluation(m);
    }

    void runGeneration(std::function<float (T & member)> fitnessEvaluation)
    {
        double minFitness = 999999.0;
        double maxFitness = -999999.0;
        mGenerationCount++;

        int populationSize = mPopulation.size();
        assert(populationSize <= kInitialPopulationSize);
        
        // Generate fitness scores
        std::vector<std::thread> threads(populationSize);

#define USE_THREADS 1
        
        for (int i = 0; i < populationSize; ++i)
        {
            T & m = mPopulation[i];
#if USE_THREADS
            threads.at(i) =             std::thread(&GeneticPopulation<T>::threadEval,
                                                    this,
                                                    i,
                                                    std::ref(fitnessEvaluation),
                                                    std::ref(m));
#else 
            memberFitnesses[i] = fitnessEvaluation(m);
#endif
        }

#if USE_THREADS
        for (int i = 0; i < populationSize; ++i)
        {
            threads.at(i).join();
        }
#endif
        
        // Create a range of scores
        for ( int i = 0; i < populationSize; ++i)
        {
            double memberFitness = mFitnessScores[i];
            if (memberFitness < minFitness)
            {
                minFitness = memberFitness;
            }
            if (memberFitness > maxFitness)
            {
                maxFitness = memberFitness;
                mFittestMember = mPopulation[i];
            }
        }
        
        // Create the mating pool
        std::vector<T> matingPool;
        for (int i = 0; i < populationSize; ++i)
        {
            double fitness = mFitnessScores[i];
            // NOTE: max possible reproduction count is the same as the population size.
            int mappedFitness = ci::lmap<double>(fitness, minFitness, maxFitness, 1.0, (double)mPopulationSize);
            // Account for cases where all candidates have the same weight
            if (minFitness == maxFitness)
            {
                // std::cout << "Setting mappedFitness\n";
                mappedFitness = 1;
            }

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

    double mFitnessScores[kInitialPopulationSize];
    int mPopulationSize;
    std::vector<T> mPopulation;
    T mFittestMember;
    long mGenerationCount;
    
};