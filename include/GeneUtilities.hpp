//
//  GeneUtilities.hpp
//  BestFontCV
//
//  Created by William Lindmeier on 11/18/13.
//
//

#pragma once

#include "BestFontConstants.h"

static float RandScalar()
{
    return (int)(arc4random() % 100000) * 0.00001;
}

static bool RandBool()
{
    return RandScalar() < .5f;
}

static bool ShouldMutate()
{
    return RandScalar() < kMutationRate;
}