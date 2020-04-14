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
  file('**/**/*report*.pdf') into html_report
  file("*") into all_results

  script:
  
  optional_argument = vep.endsWith("no_vepFile.txt") ? '' : "--vepFile ${vep}"

  """
  genomechronicler \
  --resultsDir '/GenomeChronicler' \
  --bamFile $bam \
  $optional_argument &> STDERR.txt

  cp -r /GenomeChronicler/results/results_${bam.simpleName} .
  mv STDERR.txt results_${bam.simpleName}/

  mkdir dump
  cp -r /GenomeChronicler/ dump
  """
}

process pdf2html {
  tag "$bam"
  publishDir "$params.outdir/MultiQC/", mode: 'copy'
  container 'darrenmei96/pdf2htmlex-with-msfonts'

  input:
  file(pdf_report) from html_report

  output:
  file("*") into html_result

  script:

  """
  pdf2htmlEX $pdf_report
  mv ${pdf_report.baseName}.html multiqc_report.html
  """
}
