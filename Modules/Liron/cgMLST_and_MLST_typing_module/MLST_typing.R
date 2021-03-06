# AUTHOR: Menachem Sklarz & Michal Gordon

library(magrittr)
library(plyr)
library("optparse")
library(tools)


# paste("Rscript",
#       "MLST_typing.R",
#       "--blast",    "StaphAureus/SAM1313.blast.parsed",
#       "--scheme",   "StaphAureus/SA_MLST_scheme_new..txt",
#       "--num_of_genes",   "7",
#       "--output",   "StaphAureus/SAH401.MLST.txt") %>% system
# paste("Rscript","MLST_typing.R","-h") %>% system


args = commandArgs(trailingOnly=TRUE)

option_list = list(
  make_option(c("-b", "--blast"), type="character", default=NULL, 
              help="Path to PARSED blast results", metavar="character"),
  make_option(c("-s", "--scheme"), type="character", default=NULL, 
              help="Path to tab-delimited MLST scheme WITH TITLE LINE.", metavar="character"),
  make_option(c("-n", "--num_of_genes"), type="numeric", default=7, 
              help="Number f genes (= number of columns after first ST column which represent genes) (default: 7)", metavar="character"),
  make_option(c("-o", "--output"), type="character", default=NULL, 
              help="Path to output file (default=<blast_input>.MLST)", metavar="character"),
  make_option(c("-c", "--cols_to_return"), type="character", default = "ST", 
              help="Columns in the scheme table to return", metavar="character"),
  make_option(c("-F", "--Find_close_match"), type="character", default = "N", 
              help="whether to show the closest allele match? (Y/N)", metavar="character")
); 



opt_parser = optparse::OptionParser(usage = "usage: %prog [options]", 
                                    option_list=option_list,
                                    epilogue="\n\nAuthor: Menachem Sklarz");
opt = optparse::parse_args(opt_parser);
# 
#  opt$blast = "E:\\levinl\\Koby\\04.Campylobacter_jejuni\\cgMLST\\43379.blast.parsed"
#  opt$output = "E:\\levinl\\Koby\\04.Campylobacter_jejuni\\cgMLST\\MLST.txt"
#  opt$num_of_genes = 1343
#  opt$cols_to_return = "cgST"
#  opt$scheme = "E:\\levinl\\Koby\\04.Campylobacter_jejuni\\cgMLST\\cgMLST.tsv"

opt$cols_to_return <- strsplit(x = opt$cols_to_return,
                               split = ",") %>% unlist

# REad mlst scheme
mlst <- read.delim(opt$scheme,
                   he = T,
                   stringsAsFactors = F)

gene_names = names(mlst)[2:(opt$num_of_genes+1)]

#seting the default in status new column
mlst[dim(mlst)[1]+1,"Status"]=''
mlst["Status"]="OK"
mlst["Percentage_of_missing_genes"]=0
#adding sample name

sample<- strsplit(x = opt$blast,
              split = "/")%>% unlist %>% tail(.,n=1) %>% strsplit(.,split=".blast.parsed") %>% unlist
mlst["Sample"]=sample


# Read BLAST data:
blast_raw <- read.delim(opt$blast,
                        he = T,
                        stringsAsFactors = F)
# Set Gene as rowname
rownames(blast_raw) <- blast_raw$Gene
blast_raw<-blast_raw[intersect(blast_raw$Gene,gene_names),]

if (length(blast_raw$Gene) < opt$num_of_genes){
 
  #sending erorr
  non_existing_allel <- setdiff(gene_names,blast_raw$Gene)
  write(sprintf("Genes %s not found",
                paste(non_existing_allel,
                      collapse = " ")), 
        file = stderr())
  
  mlst["Status"]=sprintf("Genes %s not found",
                         paste(non_existing_allel,
                               collapse = " "))
  mlst["Percentage_of_missing_genes"]=length(non_existing_allel)/opt$num_of_genes
  # Removing non-perfectly matching alleles
  blast <- blast_raw[(blast_raw$pident==100 & blast_raw$coverage==100),]
  
  # Finding genes in scheme not found perfectly in sample
  non_existing_allel <- setdiff(blast_raw$Gene,blast$Gene)
  if (length(non_existing_allel) > 0) {
    
    write(sprintf("Genes %s not found perfectly",
                  paste(non_existing_allel,
                        collapse = " ")), 
          file = stderr())
    #informing the not perfect match in the status column 
    mlst["Status"]=paste( mlst[dim(mlst)[1],"Status"] , sprintf("Genes %s not found perfectly",
                           paste(non_existing_allel,
                                 collapse = " ")),sep=" / ")
  }
  if (opt$Find_close_match=='Y'){
      #adding new line in the scheme
      mlst[dim(mlst)[1],blast_raw$Gene]=blast_raw[blast_raw$Gene,"Number"]
  }else{
    #adding new line in the scheme
    mlst[dim(mlst)[1],blast$Gene]=blast[blast$Gene,"Number"]
    #adding new alleles to the scheme
    mlst[dim(mlst)[1],non_existing_allel]=sapply(X = blast_raw[non_existing_allel,"sseq"]  , FUN = function(x) paste("New_Allele=",stringi::stri_replace_all(str = x,replacement ='',regex = '-') ,sep = "")) 
    }
  write.table(x         = mlst[dim(mlst)[1],,drop=F] , 
              file      = opt$output,
              sep       = "\t",
              row.names = F,
              quote     = F,
              col.names = T)
  
  } else {
    # Removing non-perfectly matching alleles
    blast <- blast_raw[(blast_raw$pident==100 & blast_raw$coverage==100),]
    
    
    # Finding genes in scheme not found perfectly in sample
    non_existing_allel <- setdiff(gene_names,blast$Gene)
    if (length(non_existing_allel) > 0) {
 
      write(sprintf("Genes %s not found perfectly",
                    paste(non_existing_allel,
                          collapse = " ")), 
            file = stderr())
    #informing the not perfect match in the status column 
    mlst["Status"]=sprintf("Genes %s not found perfectly",
                           paste(non_existing_allel,
                                 collapse = " "))
    
    if (opt$Find_close_match=='Y'){
        #going back before the identity cutoff 
        blast <- blast_raw
    }else{
      #going back before the identity cutoff 
      blast <- blast_raw
      #adding new alleles to the scheme
      blast[non_existing_allel,"Number"]=sapply(X = blast_raw[non_existing_allel,"sseq"]  , FUN = function(x) paste("New_Allele=",stringi::stri_replace_all(str = x,replacement ='',regex = '-') ,sep = "")) 
    }
    
    }



           
if ((dim(mlst)[1]-1)>0){
    MLST_num <- sapply(X      = 1:(dim(mlst)[1]-1), 
                      FUN    = function(x) all(mlst[x,gene_names]  ==blast[gene_names,"Number"])  ) 
}else{
    MLST_num=0
}


if(sum(MLST_num) == 0) {
  
  write("Allele combination not found in scheme", file = stderr())
  mlst[dim(mlst)[1],blast$Gene]=blast[blast$Gene,"Number"]
  #adding new alleles to the scheme
  mlst[dim(mlst)[1],non_existing_allel]=sapply(X = blast_raw[non_existing_allel,"sseq"]  , FUN = function(x) paste("New_Allele=",stringi::stri_replace_all(str = x,replacement ='',regex = '-') ,sep = "")) 
  if (mlst[dim(mlst)[1],"Status"]=="OK") {
      mlst["Status"]="Allele combination not found in scheme"
  } else {
      mlst["Status"]=paste( mlst[dim(mlst)[1],"Status"] , sprintf("Allele combination not found in scheme"),
                            sep=" / ")                                                                      
  }
  
  
  mlst["Sample"]=sample
  write.table(x         = mlst[dim(mlst)[1],,drop=F] , 
              file      = opt$output,
              sep       = "\t",
              row.names = F,
              quote     = F,
              col.names = T)
  
} else if(sum(MLST_num) > 1) {
  write("Allele combination appears more than once in scheme", file = stderr())
  mlst[dim(mlst)[1],blast$Gene]=blast[blast$Gene,"Number"]
  if (mlst[dim(mlst)[1],"Status"]=="OK") {
    mlst["Status"]="Allele combination appears more than once in scheme"
  }else {
    mlst["Status"]=paste( mlst[dim(mlst)[1],"Status"] , sprintf("Allele combination appears more than once in scheme"),
                          sep=" / ")                                                                      
  }
  
  mlst["Sample"]=sample
  write.table(x         = mlst[dim(mlst)[1],,drop=F] , 
              file      = opt$output,
              sep       = "\t",
              row.names = F,
              quote     = F,
              col.names = T)
} else {
  if (mlst[dim(mlst)[1],"Status"]!="OK") {
    write("Found the closest allele combination", file = stderr())
    mlst["Status"]=paste( mlst[dim(mlst)[1],"Status"] , sprintf("Found the closest allele combination"),
                          sep=" / ")  
  }
  write.table(x         = mlst[which(MLST_num),,drop=F] , 
              file      = opt$output,
              sep       = "\t",
              row.names = F,
              quote     = F,
              col.names = T)
}
}