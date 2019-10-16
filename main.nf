Channel
    .fromPath(params.bamFile)
    .ifEmpty { exit 1, "--bamFile not specified or no file found at that destination with the suffix .bam. Please make sure to provide the file path correctly}" }
    .set { chronicler_bam }


if (params.vepFile) {
    Channel.fromPath(params.vepFile)
           .ifEmpty { exit 1, "--vepFile not specified or no file found at that destination with the suffix .html. Please make sure to provide the file path correctly}" }
           .set { chronicler_vep }
}

process genomechronicler {
  tag "$bam"
  publishDir "$params.outdir/GenomeChronicler", mode: 'copy'

  input:
  file(bam) from chronicler_bam
  file(vep) from chronicler_vep

  output:
  file("*") into chronicler_results

  script:
  
  optional_argument = params.vepFile.endsWith("no_vepFile.txt") ? '' : "--vepFile ${vep}"

  """
  genomechronicler \
  --bamFile $bam !optional_argument
  """
}