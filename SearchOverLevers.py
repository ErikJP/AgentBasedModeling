from ema_workbench import SequentialEvaluator, ema_logging, MultiprocessingEvaluator, perform_experiments
from ema_workbench import RealParameter, ScalarOutcome, Constant, Model, Constraint
from ema_workbench.em_framework.optimization import (HyperVolume, EpsilonProgress)

import numpy as np
import pandas as pd
import pyNetLogo
import os

from ema_workbench.connectors.netlogo import NetLogoModel

ema_logging.log_to_stderr(ema_logging.INFO)

if __name__ == '__main__':

    model = NetLogoModel("PoRModel", wd="./", model_file='git/model/PoR_Model.nlogo')
    model.run_length = 31
    model.replications = 10
    
    #netlogo = pyNetLogo.NetLogoLink(gui=False)
    #netlogo.load_model(os.path.abspath('git/model/PoR_Model.nlogo'))

    #netlogo.command('setup')
    
    # set levers
    model.levers = [RealParameter('total-available-subsidy', 0, 100000000),
                    RealParameter('subsidy-for-industries', 0, 200),
                    RealParameter('total-subsidy-increase-for-target', 0, 15),
                    RealParameter('industry-subsidy-increase-for-target', 0, 15),
                    RealParameter('extensible-storage-price', 0, 50)]
  
    #model.outcomes = [ScalarOutcome('co2 emitted to air', ScalarOutcome.MINIMIZE, variable_name='total-co2-emitted-to-air-global',
    #                               function=np.sum),
    #                 ScalarOutcome('total co2 stored', ScalarOutcome.MAXIMIZE, variable_name='total-co2-stored-global',
    #                               function=np.sum),
    #                 ScalarOutcome('total subsidy PoRA', ScalarOutcome.MINIMIZE, variable_name='total-subsidy-to-por-global', 
    #                               function=np.max),
    #                 ScalarOutcome('total subsidy industries', ScalarOutcome.MINIMIZE, variable_name='total-subsidy-to-industries-global', 
    #                               function=np.max)]

    #model.outcomes = [ScalarOutcome('lastvalue-co2-emitted-to-air-global', ScalarOutcome.MINIMIZE),
    #                 ScalarOutcome('sum-co2-emitted-to-air-global', ScalarOutcome.MAXIMIZE),
    #                 ScalarOutcome('sum-subsidy-to-por-global', ScalarOutcome.MINIMIZE),
    #                 ScalarOutcome('sum-subsidy-to-industries-global', ScalarOutcome.MINIMIZE)]
    
    #np.max is used as the outcome is a list of one value 
    #-> it doesn't matter which function is used to extract it, np.max was chosen arbitrarily
    model.outcomes = [ScalarOutcome('2050 yearly CO2 emitted', ScalarOutcome.MINIMIZE, 
                                    variable_name='lastvalue-co2-emitted-to-air-global',
                                    function=np.max),
                     ScalarOutcome('sum-co2-emitted-to-air-global', ScalarOutcome.MAXIMIZE,
                                    variable_name='sum-co2-emitted-to-air-global',
                                    function=np.max),
                     ScalarOutcome('sum-subsidy-to-por-global', ScalarOutcome.MINIMIZE,
                                    variable_name='sum-subsidy-to-por-global',
                                    function=np.max),
                     ScalarOutcome('sum-subsidy-to-industries-global', ScalarOutcome.MINIMIZE,
                                    variable_name='sum-subsidy-to-industries-global',
                                    function=np.max)]
    
    convergence = [HyperVolume(minimum=[0,0,0,0], maximum=[1e9,1e9,1e8,1e8]), EpsilonProgress()]

    with SequentialEvaluator(model) as evaluator:
        results, convergence = evaluator.optimize(nfe=10000, searchover='levers', epsilons=[0.1,]*len(model.outcomes), 
                                                  convergence = convergence, logging_freq=10, convergence_freq=100)
    
    results.to_csv('./data/MORDM_nfe100.csv')
    convergence.to_csv('./data/MORDM_nfe100_conv.csv')