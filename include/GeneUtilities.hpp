//
//  GeneUtilities.hpp
//  BestFontCV
//
//  Created by William Lindmeier on 11/18/13.
//
//

#pragma once

const static float kMutationRate = 0.01;

static float RandScalar()
{
    return (int)(arc4random() % 10000) * 0.0001;
}

static bool RandBool()
{
    return RandScalar() < .5f;
}

static bool ShouldMutate()
{
    return RandScalar() < kMutationRate;
}