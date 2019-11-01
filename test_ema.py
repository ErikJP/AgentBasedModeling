
from multiprocessing import Pool
import os
import pandas as pd

import pyNetLogo
from SALib.sample import saltelli

def initializer(modelfile):
    '''initialize a subprocess

    Parameters
    ----------
    modelfile : str

    '''

    # we need to set the instantiated netlogo
    # link as a global so run_simulation can
    # use it
    global netlogo

    netlogo = pyNetLogo.NetLogoLink(gui=False)
    netlogo.load_model(modelfile)
    
def run_simulation(experiment):
    '''run a netlogo model

    Parameters
    ----------
    experiments : dict

    '''

    #Set the input parameters
    for key, value in experiment.items():
        if key == 'random-seed':
            #The NetLogo random seed requires a different syntax
            netlogo.command('random-seed {}'.format(value))
        else:
            #Otherwise, assume the input parameters are global variables
            netlogo.command('set {0} {1}'.format(key, value))

    netlogo.command('setup')

    counts = netlogo.repeat_report(['total-co2-emitted-to-air-global','total-co2-stored-global', 'total-subsidy-to-por-global', 'total-subsidy-to-industries-global'], 31)

    results = pd.Series([counts['total-co2-emitted-to-air-global'].values.mean(),
                         counts['total-co2-stored-global'].values.mean(),
                         counts['total-subsidy-to-por-global'].values.mean(),
                         counts['total-subsidy-to-industries-global'].values.mean()
                         ])
    return results

if __name__ == '__main__':
    modelfile = os.path.abspath('git/model/PoR_Model.nlogo')

    problem = {
      'num_vars': 5,
      'names': ['total-available-subsidy',
                'subsidy-for-industries',
                'total-subsidy-increase-for-target',
                'industry-subsidy-increase-for-target',
                'extensible-storage-price'
               ],
      'bounds': [[1, 10000000],
                 [1, 200],
                 [0, 15],
                 [0, 15],
                 [0, 50]]
    }

    n = 10000
    param_values = saltelli.sample(problem, n,
                               calc_second_order=True)

    # cast the param_values to a dataframe to
    # include the column labels
    experiments = pd.DataFrame(param_values,
                               columns=problem['names'])


    with Pool(4, initializer=initializer, initargs=(modelfile,)) as executor:
        results = []
        for entry in executor.map(run_simulation, experiments.to_dict('records')):
            results.append(entry)
        results = pd.DataFrame(results)
        
        results.to_csv('./data/Sobol_191029_10000_results.csv')
        experiments.to_csv('./data/Sobol_191029_10000_experiments.csv')