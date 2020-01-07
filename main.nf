Channel
    .fromPath(params.bamFile)
    .ifEmpty { exit 1, "--bamFile not specified or no file found at that destination with the suffix .bam. Please make sure to provide the file path correctly}" }
    .set { chronicler_bam }

Channel.fromPath(params.vepFile)
        .ifEmpty { exit 1, "--vepFile not specified or no file found at that destination with the suffix .html. Please make sure to provide the file path correctly}" }
        .set { chronicler_vep }

process genomechronicler {
  tag "$bam"
  publishDir "$params.outdir/GenomeChronicler", mode: 'copy'

  input:
  file(bam) from chronicler_bam
  file(vep) from chronicler_vep

  output:
  file("*") into chronicler_results

  script:
  
  optional_argument = vep.endsWith("no_vepFile.txt") ? '' : "--vepFile ${vep}"

  """
  genomechronicler \
  --bamFile $bam $optional_argument
  """
}

// Unwinding refactoring

// If we are running VEP, call script or function to process the HTML into the needed tables
process CreateVEPTables {

  tag "$bam"
  publishDir "$params.outdir/placeholder/results_${sample}/", mode: 'copy'

  input:
  file(vep) from chronicler_vep

  output:
  file("*{placeholder_vep_tables}") into chronicler_results

  script:
  
  when: params.vep

  """
  GenomeChronicler_vepTables_fromVEP.pl  $vep_file
  """
}

//  Run script or subroutine to make sure that we don't have 'chr' in the contig names
process RenameChromPrefix {
  tag "$bam"
  publishDir "$params.outdir/GenomeChronicler", mode: 'copy'

  input:
  file(bam) from chronicler_bam

  output:
  file("*") into chronicler_results

  script:
  
  """
  #!/usr/bin/env perl

  if(defined($BAM_file)) {

    print STDERR "\t +++ INFO: Preprocessing BAM file\n";	
    
    if((!-e $BAM_file.".clean.BAM") or (!-e $BAM_file.".clean.BAM.bai")) {
      &cleanBAMfile_noCHR($BAM_file);
    }

    $BAM_file = $BAM_file.".clean.BAM";
  }
  """
}

// Use the BAM to call the right script to compute currentAncestryPlot
process InferAncestry {

  tag "$bam"
  publishDir "$params.outdir/Ancestry", mode: 'copy'

  input:
  file(bam) from chronicler_bam
  file(vep) from chronicler_vep

  output:
  file("*") into chronicler_results

  script:
  
  optional_argument = vep.endsWith("no_vepFile.txt") ? '' : "--vepFile ${vep}"

  """
  #!/usr/bin/env perl

  GenomeChronicler_ancestry_generator_fromBAM.pl \
  $BAM_file \
  $resultsdir \
  $GATKthreads ${task.cpus}
  """
}

// Use the BAM to call the right script to compute currentAncestryPlot
process PlotAncestry {

  tag "$bam"
  publishDir "$params.outdir/Ancestry/", mode: 'copy'

  input:
  file(sample) from chronicler_bam
  file(id) from chronicler_vep

  output:
  file("*") into chronicler_results

  script:

  """
  GenomeChronicler_plot_generator_fromAncestry.R \
  --id ${sample.simpleName} \
  --sample ${sample}
  """
}

// Use the BAM to call the genotypes on the needed positions for this
process CallVariants {

  tag "$bam"
  publishDir "$params.outdir/GenomeChronicler", mode: 'copy'

  input:
  file(bam) from chronicler_bam

  output:
  file("*afogeno38.txt") into ch_report_tables

  script:

  """
  GenomeChronicler_afogeno_generator_fromBAM.pl
  $BAM_file \
  $resultsdir . \
  $GATKthreads ${task.cpus}
  """
}

// Use the generated genotypes file to produce the report tables by linking with the databases
process GenerateReportTables {

  tag "$bam"
  publishDir "$params.outdir/results_${sample}", mode: 'copy'

  input:
  val(sample) from chronicler_bam
  file(afogeno_file) from chronicler_bam

  output:
  file("*") into chronicler_results

  script:

  """
  GenomeChronicler_genoTables_fromAfoGeno.pl $afogeno_file
  """
}

// Table filtering for variants that have 0 magnitude and/or are unsupported by external links.
process FilterReportTables {

  tag "$bam"
  publishDir "$params.outdir/results_${sample}", mode: 'copy'

  input:
  val(sample) from chronicler_bam
  file(afogeno_file) from chronicler_bam
  file(latest.good.reportTable.csv)
  file(latest.bad.reportTable.csv)

  output:
  file("*") into chronicler_results

  script:

  """
  GenomeChronicler_quickFilterFinalReportTables.pl $latest.good.reportTable.csv
  GenomeChronicler_quickFilterFinalReportTables.pl $latest.bad.reportTable.csv
  """
}

// Call script to summarise found phenotypes as XLS spreadsheet
process SummarisePhenotypes {

  tag "$bam"
  publishDir "$params.outdir/results_${sample}", mode: 'copy'

  input:
  val(sample) from chronicler_bam
  file(afogeno_file) from chronicler_bam
  file(latest.good.reportTable.csv) from 
  file(latest.bad.reportTable.csv)

  output:
  file("*") into chronicler_results

  script:

  """
  GenomeChronicler_XLSX_fromTables.pl \
  ${sample_folder_with_results} \
  ${sample}_genotypes_${dtag}.xlsx"
  """
}

// Call script to summarise found phenotypes as XLS spreadsheet
process CompileGenomeReport {

  tag "$bam"
  publishDir "$params.outdir/results_${sample}", mode: 'copy'

  input:
  file(templatetex) from ch_tex_template

  output:
  file("*") into chronicler_results

  script:
  // Check this awesome pipeline for example TeX: MaxUlysse/compile-latex/blob/master/main.nf
  // Very WIP script
  """
  &runLatex();

  sub runLatex {
      local $CWD = "${resultsdir}/results/results_${sample}";

    for(my $i = 0; $i < 3 ; $i++) {
      system("pdflatex -interaction=nonstopmode ${templatetex} .tex
    }
  }
  """
}