# -*- coding: UTF-8 -*-
""" 
``quast`` (Included in main NeatSeq-Flow repo)
-----------------------------------------------------------------

:Authors: Menachem Sklarz
:Affiliation: Bioinformatics core facility
:Organization: National Institute of Biotechnology in the Negev, Ben Gurion University.

A module for running quast on fasta assemblies:

QUAST is executed on the fasta file along the following lines:

* If 'scope' is specified, the appropriate fasta will be used. An error will occur if the fasta does not exist.
* If 'scope' is not specified, if a project-wide fasta exists, it will be used. Otherwise, sample-wise fasta files will be used. If none exist, an error will occur.

Requires
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

* fasta files in one of the following slots:

    * ``sample_data["fasta.nucl"]``
    * ``sample_data[<sample>]["fasta.nucl"]``
    

Output
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

* Puts output directory in one of:
    * ``self.sample_data["quast"]``
    * ``self.sample_data[<sample>]["quast"]``

Parameters that can be set
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. csv-table:: 
    :header: "Parameter", "Values", "Comments"
    :widths: 15, 10, 10

    "scope", "project | sample", "Indicates whether to use a project or sample bowtie2 index."
    "compare_mode", "", "If 'scope' is 'sample', specifies wether to analyse each sample separately or to create a single comparison report for all samples."

Lines for parameter file
~~~~~~~~~~~~~~~~~~~~~~~~~~~~


::

    quast1:
        module: quast
        base: spades1
        script_path: /path/to/quast.py
        compare_mode: null
        scope: project
        redirects:
            --fast: null

References
~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Gurevich, A., Saveliev, V., Vyahhi, N. and Tesler, G., 2013. **QUAST: quality assessment tool for genome assemblies**. *Bioinformatics*, 29(8), pp.1072-1075.

"""



import os
import sys
import re
from PLC_step import Step,AssertionExcept


__author__ = "Menachem Sklarz"
__version__ = "1.1.0"


class Step_quast(Step):

    
    def step_specific_init(self):
        """ Called on intiation
            Good place for parameter testing.
            Wrong place for sample data testing
        """
        self.shell = "csh"      # Can be set to "bash" by inheriting instances
        self.file_tag = ".quast.out"


    def step_sample_initiation(self):
        """ A place to do initiation stages following setting of sample_data
        """
        
        if "scope" in self.params.keys():
            if self.params["scope"] == "project":
                try:  # Is there a mega-assembly?
                    self.sample_data["fasta.nucl"]
                except KeyError:   # No. Check if all samples have assemblies:
                    raise AssertionExcept("No project wide assembly!")
                else:
                    pass

                if "compare_mode" in self.params.keys():
                    self.write_warning("Ignoring 'compare_mode' in project scope")
            
            elif self.params["scope"] == "sample":
                for sample in self.sample_data["samples"]:      # Getting list of samples out of samples_hash
                
                    # Make sure each sample has a ["fasta.nucl"] slot 
                    try:
                        self.sample_data[sample]["fasta.nucl"]
                    except KeyError:
                        raise AssertionExcept("You are trying to run QUAST with no assembly.\n" , sample)
                    else:
                        pass
            else:
                raise AssertionExcept("'scope' must be either 'project' or 'sample'")
            
        
        
        
        else:
            self.write_warning("'scope' not passed. Will try guessing...")

            try:  # Is there a mega-assembly?
                self.sample_data["fasta.nucl"]
            except KeyError:   # No. Check if all samples have assemblies:
                for sample in self.sample_data["samples"]:      # Getting list of samples out of samples_hash
                
                    # Make sure each sample has a ["fasta.nucl"] slot 
                    try:
                        self.sample_data[sample]["fasta.nucl"]

                    except KeyError:
                        raise AssertionExcept("You are trying to run QUAST with no assembly.\n" , sample)
                
                self.params["scope"] = "sample"
                
            else:
                self.write_warning("There is a project-wide assembly. Using it.\n")
        
                self.params["scope"] = "project"
        
    def create_spec_wrapping_up_script(self):
        """ Add stuff to check and agglomerate the output data
        """
        
    
    def build_scripts(self):
        """ This is the actual script building function
            Most, if not all, editing should be done here 
            HOWEVER, DON'T FORGET TO CHANGE THE CLASS NAME AND THE FILENAME!
        """
        
        
        if self.params["scope"] == "sample": # Requested for mega-assembly

            if "compare_mode" in self.params.keys():    # Compare sample assemblies
            
                # Name of specific script:
                self.spec_script_name = "_".join([self.step,self.name,self.sample_data["Title"]])
                self.script = ""

                
                # This line should be left before every new script. It sees to local issues.
                # Use the dir it returns as the base_dir for this step.
                use_dir = self.local_start(self.base_dir)
                    
                # Define output filename 
                # output_filename = "".join([use_dir , sample , self.file_tag])

                self.script += self.get_script_const()

                # All other parameters are redirected!
                self.script += "--output-dir %s \\\n\t" % use_dir
                self.script += "--labels %s \\\n\t" % ",".join(self.sample_data["samples"])
                
                # Input file:
                for sample in self.sample_data["samples"]:      # Getting list of samples out of samples_hash
                    self.script += "%s \\\n\t" % self.sample_data[sample]["fasta.nucl"]

                self.script = self.script.rstrip("\\\n\t")
                self.script += "\n\n"
                

            
                self.sample_data["quast"] = self.base_dir
            

                # Wrapping up function. Leave these lines at the end of every iteration:
                self.local_finish(use_dir,self.base_dir)       # Sees to copying local files to final destination (and other stuff)
                          
                
                self.create_low_level_script()

            else:       # Separate quast run for each sample
                for sample in self.sample_data["samples"]:      # Getting list of samples out of samples_hash
                    
                    # Name of specific script:
                    self.spec_script_name = "_".join([self.step,self.name,sample])
                    self.script = ""

                    # Make a dir for the current sample:
                    sample_dir = self.make_folder_for_sample(sample)
                    
                    # This line should be left before every new script. It sees to local issues.
                    # Use the dir it returns as the base_dir for this step.
                    use_dir = self.local_start(sample_dir)
                        
                        
                    # Define output filename 
                    # output_filename = "".join([use_dir , sample , self.file_tag])

                    self.script += self.get_script_const()

                    # All other parameters are redirected!
                    self.script += "--output-dir %s \\\n\t" % sample_dir
                    
                    # Input file:
                    self.script += "%s \n\n" % self.sample_data[sample]["fasta.nucl"]
                    

                
                    # Store BLAST result file:
                    self.sample_data[sample]["quast"] = sample_dir

                    # Wrapping up function. Leave these lines at the end of every iteration:
                    self.local_finish(use_dir,sample_dir)       # Sees to copying local files to final destination (and other stuff)
                              
                    
                    self.create_low_level_script()

        else:    # 'scope' = project
            
            # Name of specific script:
            self.spec_script_name = "_".join([self.step,self.name,self.sample_data["Title"]])
            self.script = ""

            
            # This line should be left before every new script. It sees to local issues.
            # Use the dir it returns as the base_dir for this step.
            use_dir = self.local_start(self.base_dir)
                
                
            # Define output filename 
            # output_filename = "".join([use_dir , sample , self.file_tag])

            self.script += self.get_script_const()

            # All other parameters are redirected!
            self.script += "--output-dir %s \\\n\t" % use_dir
            
            # Input file:
            self.script += "%s \n\n" % self.sample_data["fasta.nucl"]
            

        
            # Store BLAST result file:
            self.sample_data["quast"] = self.base_dir


            # Wrapping up function. Leave these lines at the end of every iteration:
            self.local_finish(use_dir,self.base_dir)       # Sees to copying local files to final destination (and other stuff)
                      
            
            self.create_low_level_script()

                    
    def make_sample_file_index(self):
        """ Make file containing samples and target file names for use by kraken analysis R script
        """
        
        pass