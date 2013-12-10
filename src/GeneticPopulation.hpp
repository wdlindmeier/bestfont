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
#include <limits>

template <class T>
class GeneticPopulation
{

public:

    GeneticPopulation(const int initialPopulationSize) :
    mPopulationSize(initialPopulationSize)
    ,mGenerationCount(0)
    ,mPopMinFitness(std::numeric_limits<double>::max())
    ,mPopMaxFitness(std::numeric_limits<double>::min())
    ,mBatchOffset(0)
    ,mFitnessScores(new double [initialPopulationSize])
    {
        initializeRandomPopulation();
    }
    
    ~GeneticPopulation()
    {
        // Why dont I have to delete this?
        // App is crashing when I do.
        // delete(mFitnessScores);
    };
    
    std::vector<T> & getPopulation()
    {
        return mPopulation;
    }
    
    // NOTE: This is the fittest member from the LAST batch.
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

    void runGenerationBatch(const int numBatches, std::function<float (T & member)> fitnessEvaluation)
    {
        int membersPerBatch = ceil((float)mPopulation.size() / (float)numBatches);
        int memberStart = mBatchOffset;
        int memberEnd = std::min<int>(memberStart + membersPerBatch, mPopulationSize);
        int batchSize = memberEnd - memberStart;
        mBatchOffset = memberEnd;

        // Generate batch fitness scores
#define USE_THREADS 1
        
#if USE_THREADS
        std::vector<std::thread> threads(batchSize);
#endif

        for (int i = 0; i < batchSize; ++i)
        {
            int memberIndex = memberStart + i;
            T & m = mPopulation[memberIndex];
#if USE_THREADS
            threads.at(i) = std::thread(&GeneticPopulation<T>::threadEval,
                                        this,
                                        memberIndex,
                                        std::ref(fitnessEvaluation),
                                        std::ref(m));
#else
            memberFitnesses[memberIndex] = fitnessEvaluation(m);
#endif
        }
        
#if USE_THREADS
        for (int i = 0; i < batchSize; ++i)
        {
            threads.at(i).join();
        }
#endif

        // Update a range of scores and pick the current fittest
        for ( int i = memberStart; i < memberEnd; ++i )
        {
            double memberFitness = mFitnessScores[i];
            if (memberFitness < mPopMinFitness)
            {
                mPopMinFitness = memberFitness;
            }
            if (memberFitness > mPopMaxFitness)
            {
                mPopMaxFitness = memberFitness;
                mFittestMember = mPopulation[i];
            }
        }
        
        if (mBatchOffset >= mPopulationSize)
        {
            // This batch is the end of the generation.
            // Wrap it up and create a new generation.
            mGenerationCount++;
            mBatchOffset = 0;
            procreate();
            mPopMinFitness = std::numeric_limits<double>::max();
            mPopMaxFitness = std::numeric_limits<double>::min();
        }
    }
    
    void runGeneration(std::function<float (T & member)> fitnessEvaluation)
    {
        runGenerationBatch(1, fitnessEvaluation);
    }
    
    void procreate()
    {
        // Create the mating pool
        std::vector<T> matingPool;
        for (int i = 0; i < mPopulationSize; ++i)
        {
            double fitness = mFitnessScores[i];
            // NOTE: max possible reproduction count is the same as the population size.
            int mappedFitness = ci::lmap<double>(fitness, mPopMinFitness, mPopMaxFitness, 1.0, (double)mPopulationSize);
            // Account for cases where all candidates have the same weight
            if (mPopMinFitness == mPopMaxFitness)
            {
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
        
        assert(mPopulation.size() == mPopulationSize);
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

    double *mFitnessScores;
    int mPopulationSize;
    std::vector<T> mPopulation;
    T mFittestMember;
    long mGenerationCount;
    double mPopMinFitness;
    double mPopMaxFitness;
    int mBatchOffset;
    
};