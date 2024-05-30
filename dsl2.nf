#!/usr/bin/env nextflow

nextflow.enable.dsl=2

params.userid = ''
params.batch = ''
params.cellline = ''
params.nreplicates = '5'
params.outlier = 'false'
params.cellprofanalysis = ''
params.lettertonum = "/home2/${params.userid}/nextflow_docs/bin/letter_to_number.r"
params.illumpipe = '/project/shared/gcrb_igvf/htscore/workspace/pipelines/Cell_Painting_Illum_8x_remade.cppipe'
params.barcode_platemap = "/project/shared/gcrb_igvf/htscore/workspace/metadata/platemaps/${params.batch}/barcode_platemap.csv"
params.metadata = "/project/shared/gcrb_igvf/htscore/workspace/metadata/external_metadata/${params.batch}_metadata.txt"
params.platemapdir = "/project/shared/gcrb_igvf/htscore/workspace/metadata/platemaps/${params.batch}/platemap"

workflow {
    image_dir_ch = Channel.fromPath("/project/shared/gcrb_igvf/htscore/workspace/images/${params.batch}/*_1/", type: 'dir').map { [ it.name, it ] }

    pwdloaddata_ch = pwdloaddata(image_dir_ch)
    createLoadDataCsvs_ch = createLoadDataCsvs(pwdloaddata_ch, file(params.lettertonum))
    illuminationMeasurement_ch = illuminationMeasurement(createLoadDataCsvs_ch, file(params.illumpipe))
    createIllumLoadDataCsvs_ch = createIllumLoadDataCsvs(illuminationMeasurement_ch)
    cpAnalysis_ch = cpAnalysis(createIllumLoadDataCsvs_ch, file(params.cellprofanalysis))
    zipfiles_ch = zipfiles(cpAnalysis_ch)
    prepare_for_PyCyto_ch = prepare_for_PyCyto(zipfiles_ch)
    createdirs(prepare_for_PyCyto_ch, file(params.barcode_platemap), file(params.metadata), file(params.platemapdir))
}

process pwdloaddata {
    label 'coreutils'
    cache 'lenient'
    tag { plateid }

    input:
    tuple val(plateid), path(imagedir)

    output:
    tuple val(plateid), file("${plateid}_pwd.txt"), path(imagedir)

    script:
    """
    readlink ${imagedir} > ${plateid}_pwd.txt
    """
}

process createLoadDataCsvs {
    label 'pycytoandr'
    cache 'lenient'
    publishDir "/project/shared/gcrb_igvf/htscore/workspace/load_data_csv/${params.batch}/${plateid}/", mode: 'copy'
    tag { plateid }

    input:
    tuple val(plateid), file("${plateid}_pwd.txt"), path(imagedir)
    file lettertonum

    output:
    tuple val(plateid), file("${plateid}_load_data.csv"), path(imagedir)

    script:
    """
    echo ${plateid} > platename.txt
    mv platename.txt ${imagedir}
    mv ${plateid}_pwd.txt ${imagedir}
    cp ${lettertonum} ${imagedir}/letter_to_number.r
    generate_load_data.sh $imagedir
    mv ${imagedir}/load_data.csv ${plateid}_load_data.csv
    """
}

process illuminationMeasurement {
    label 'cellprof'
    cache 'lenient'
    publishDir "/project/shared/gcrb_igvf/htscore/workspace/illum/${params.batch}/${plateid}/", mode: 'copy'
    tag { plateid }

    input:
    tuple val(plateid), file("${plateid}_load_data.csv"), path(imagedir)
    file illumpipe

    output:
    tuple val(plateid), path("${plateid}_out/${plateid}_illumAGP.npy"), path("${plateid}_out/${plateid}_illumDNA.npy"), path("${plateid}_out/${plateid}_illumER.npy"), path("${plateid}_out/${plateid}_illumMito.npy"), file("${plateid}_load_data.csv"), path(imagedir)

    script:
    """
    set -e
    echo "Contents of the pipeline file:"
    cat ${illumpipe}
    echo "Copying pipeline file if necessary..."
    if [ ! -f ./Cell_Painting_Illum_8x_remade.cppipe ]; then
        cp ${illumpipe} ./Cell_Painting_Illum_8x_remade.cppipe
    fi
    echo "Pipeline file checked/copied. Checking contents of the copied file:"
    cat ./Cell_Painting_Illum_8x_remade.cppipe
    echo "Running CellProfiler..."
    cellprofiler -c -r -p Cell_Painting_Illum_8x_remade.cppipe --data-file ${plateid}_load_data.csv -i ${imagedir} -o ${plateid}_out
    echo "CellProfiler run complete."
    mv ${plateid}_out/IGVF/Plate_illumAGP.npy ${plateid}_out/${plateid}_illumAGP.npy
    mv ${plateid}_out/IGVF/Plate_illumDNA.npy ${plateid}_out/${plateid}_illumDNA.npy
    mv ${plateid}_out/IGVF/Plate_illumER.npy ${plateid}_out/${plateid}_illumER.npy
    mv ${plateid}_out/IGVF/Plate_illumMito.npy ${plateid}_out/${plateid}_illumMito.npy
    """
}

process createIllumLoadDataCsvs {
    label 'pycytoandr'
    cache 'lenient'
    publishDir "/project/shared/gcrb_igvf/htscore/workspace/load_data_csv/${params.batch}/${plateid}/", mode: 'copy'
    tag { plateid }

    input:
    tuple val(plateid), path("${plateid}_out/${plateid}_illumAGP.npy"), path("${plateid}_out/${plateid}_illumDNA.npy"), path("${plateid}_out/${plateid}_illumER.npy"), path("${plateid}_out/${plateid}_illumMito.npy"), file("${plateid}_load_data.csv"), path(imagedir)

    output:
    tuple val(plateid), file("${plateid}_load_data_with_illum.csv"), path(imagedir), file("${plateid}_load_data.csv")

    script:
    """
    echo ${plateid} > platename.txt
    generate_illumCsv.sh ${plateid}_out ${plateid}_load_data.csv
    mv ${plateid}_out/${plateid}_load_data_with_illum.csv .
    """
}

process cpAnalysis {
    label 'cellprof'
    cache 'lenient'
    publishDir "/project/shared/gcrb_igvf/htscore/workspace/profiles/${params.batch}/${plateid}/", mode: 'copy'
    tag { plateid }

    input:
    tuple val(plateid), file("${plateid}_load_data_with_illum.csv"), path(imagedir), file("${plateid}_load_data.csv")
    file analysispipe

    output:
    tuple val(plateid), path("${plateid}_out/IGVF_painting_results/${plateid}_IGVFCells.csv"), path("${plateid}_out/IGVF_painting_results/${plateid}_IGVFCytoplasm.csv"), path("${plateid}_out/IGVF_painting_results/${plateid}_IGVFNuclei.csv"), path("${plateid}_load_data_with_illum.csv"), file("${plateid}_load_data.csv")

    script:
    """
    set -e
    echo "Copying analysis pipeline file if necessary..."
    if [ ! -f ./Cell_Painting_Analysis_IGVF_loaddata.cppipe ]; then
        cp ${analysispipe} ./Cell_Painting_Analysis_IGVF_loaddata.cppipe
    fi
    echo "Analysis pipeline file checked/copied. Running CellProfiler..."
    cellprofiler -c -r -p Cell_Painting_Analysis_IGVF_loaddata.cppipe --data-file ${plateid}_load_data_with_illum.csv -i ${imagedir} -o ${plateid}_out
    echo "CellProfiler run complete."
    mv ${plateid}_out/IGVF_painting_results/IGVFCells.csv ${plateid}_out/IGVF_painting_results/${plateid}_IGVFCells.csv
    mv ${plateid}_out/IGVF_painting_results/IGVFCytoplasm.csv ${plateid}_out/IGVF_painting_results/${plateid}_IGVFCytoplasm.csv
    mv ${plateid}_out/IGVF_painting_results/IGVFNuclei.csv ${plateid}_out/IGVF_painting_results/${plateid}_IGVFNuclei.csv
    """
}

process zipfiles {
    label 'tabix'
    cache 'lenient'
    publishDir "/project/shared/gcrb_igvf/htscore/workspace/profiles/${params.batch}/${plateid}/", mode: 'copy'
    tag { plateid }

    input:
    tuple val(plateid), path("${plateid}_out/IGVF_painting_results/${plateid}_IGVFCells.csv"), path("${plateid}_out/IGVF_painting_results/${plateid}_IGVFCytoplasm.csv"), path("${plateid}_out/IGVF_painting_results/${plateid}_IGVFNuclei.csv"), path("${plateid}_load_data_with_illum.csv"), file("${plateid}_load_data.csv")

    output:
    tuple val(plateid), path("${plateid}_out/IGVF_painting_results/${plateid}_IGVFCells.csv.gz"), path("${plateid}_out/IGVF_painting_results/${plateid}_IGVFCytoplasm.csv.gz"), path("${plateid}_out/IGVF_painting_results/${plateid}_IGVFNuclei.csv.gz"), path("${plateid}_load_data.csv.gz")

    script:
    """
    bgzip -@ ${task.cpus} ${plateid}_out/IGVF_painting_results/${plateid}_IGVFCells.csv
    bgzip -@ ${task.cpus} ${plateid}_out/IGVF_painting_results/${plateid}_IGVFCytoplasm.csv
    bgzip -@ ${task.cpus} ${plateid}_out/IGVF_painting_results/${plateid}_IGVFNuclei.csv
    bgzip -@ ${task.cpus} ${plateid}_load_data.csv
    """
}

process prepare_for_PyCyto {
    label 'pycytoandr'
    cache 'lenient'
    publishDir "/project/shared/gcrb_igvf/htscore/workspace/profiles/${params.batch}/${plateid}/", mode: 'copy'
    tag { plateid }

    input:
    tuple val(plateid), path("${plateid}_out/IGVF_painting_results/${plateid}_IGVFCells.csv.gz"), path("${plateid}_out/IGVF_painting_results/${plateid}_IGVFCytoplasm.csv.gz"), path("${plateid}_out/IGVF_painting_results/${plateid}_IGVFNuclei.csv.gz"), path("${plateid}_load_data.csv.gz")

    output:
    tuple val(plateid), path("${plateid}.csv.gz"), path("${plateid}_load_data.csv.gz")

    script:
    """
    aggregate.r ${plateid}_out/IGVF_painting_results/${plateid}_IGVFCells.csv.gz ${plateid}_IGVF ${plateid}
    aggregate.r ${plateid}_out/IGVF_painting_results/${plateid}_IGVFCytoplasm.csv.gz ${plateid}_IGVF ${plateid}
    aggregate.r ${plateid}_out/IGVF_painting_results/${plateid}_IGVFNuclei.csv.gz ${plateid}_IGVF ${plateid}
    merge_aggregated.r ${plateid}_out/IGVF_painting_results/${plateid}_IGVFCells_aggregated.csv.gz ${plateid}_out/IGVF_painting_results/${plateid}_IGVFCytoplasm_aggregated.csv.gz ${plateid}_out/IGVF_painting_results/${plateid}_IGVFNuclei_aggregated.csv.gz
    """
}

process createdirs {
    label 'pycytoandr'
    cache 'lenient'
    tag { plateid }
    publishDir "/project/shared/gcrb_igvf/htscore/workspace/", mode: 'copy'

    input:
    tuple val(plateid), path("${plateid}.csv.gz"), path("${plateid}_load_data.csv.gz")
    file barcode_platemap
    file metadata
    file platemapdir

    output:
    tuple val(plateid), path("metadata/platemaps/${params.batch}/barcode_platemap.csv"), path("metadata/external_metadata/${params.batch}_metadata.txt"), path("profiles/${params.batch}/${plateid}/${plateid}.csv.gz"), path("load_data_csv/${params.batch}/${plateid}/load_data.csv.gz"), path("gct/${params.batch}/${plateid}/${plateid}.csv.gz")

    script:
    """
    mkdir -p profiles/${params.batch}/${plateid}
    mkdir -p metadata/external_metadata
    mkdir -p metadata/platemaps/${params.batch}/platemap
    mkdir -p load_data_csv/${params.batch}/${plateid}
    mkdir -p gct/${params.batch}/${plateid}

    cp ${barcode_platemap} metadata/platemaps/${params.batch}/
    cp ${platemapdir}/*_platemap.txt metadata/platemaps/${params.batch}/platemap/
    cp ${metadata} metadata/external_metadata/
    cp ${plateid}.csv.gz profiles/${params.batch}/${plateid}/
    cp ${plateid}.csv.gz gct/${params.batch}/${plateid}/
    cp ${plateid}_load_data.csv.gz load_data_csv/${params.batch}/${plateid}/
    mv load_data_csv/${params.batch}/${plateid}/${plateid}_load_data.csv.gz load_data_csv/${params.batch}/${plateid}/load_data.csv.gz
    """
}

