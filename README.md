# Late_Pleistocene_vole_from_Indigirka_project

In the Late Pleistocene deposits of the upper Indigirka River (Eastern Yakutia, Russia), paleontologists discovered a mummified vole specimen initially assigned to the narrow-headed vole Stenocranius gregalis. Subsequent morphological analysis of the masticatory surface pattern revealed affinities with the singing vole Microtus miurus, a species currently distributed exclusively in the tundra zone of North America. This finding raises an intriguing biogeographical question regarding the historical distribution of M. miurus and its potential presence in Eurasia during the Late Pleistocene. 

**Objective:** Reconstruct phylogeny and evolutionary history of *Microtus (S) stenocranius egorovi* (37,700 ± 2,200 BP, Indigirka River) using ancient DNA.

**The tasks**: 

- To perform quality control and preprocessing of raw reads;
- To estimate contamination levels and confirm the ancient origin of the sample;
- To assemble the complete mitochondrial genome of the ancient vole as well as some other Microtus species;
- To reconstruct phylogenetic trees based on complete mitogenomes and cytochrome b sequences;
- To assume the distribution of M. miurus during the Late Pleistocene.

---

## 📂 Project Structure

This repository contains the code, scripts, and minimal essential outputs. Large data files (raw FASTQ, BAM files, reference genomes, large intermediate files, Kraken2 database (223 GB)) are **not** stored in Git.

### 📦 Repository Structure (What's on GitHub)

```text
.
├── README.md                    # This file
├── environment.yml              # Conda dependencies
├── .gitignore                   # Exclusions for large files
│
├── scripts/                     # All pipeline scripts (executable)
│   ├── 01_preprocess_ancient_dna.sh
│   ├── 02_build_kraken_db.sh
│   ├── 03_map_and_damage.sh
│   ├── 04_ancient_mitogenome_assembly.sh
│   ├── 05_de_novo_mitogenome_assembly.sh
│   ├── 06_Microtus_mitogenome_phylogeny.sh
│   ├── 07_alternative_Microtus_mitogenome_phylogeny.sh
│   ├── 08_cytb_tip_dating.sh
│   ├── 09_cytb_ml_tree.sh
│   ├── rename_tree.py           # Utility: clean tree labels
│   ├── draw_tree.R              # Tree Visualization
│   └── kraken_build/
│       └── download_kraken.sh   # Helper: download genomes
│
├── figures/                     
│   ├── trees/
│   │   ├── cytb_dated_tree.jpg
│   │   └── mitogenome_tree.png
│   ├──beast2/
│   │   └── tracer_convergence.png      
│   └──kraken2/
│       └── kraken-top-n-plot.png
│   
└── results/             
    ├── trees/
    │   ├── mitogenome_tree_full.treefile     # Main ML tree
    │   ├── cytb_tree_ml_named.treefile       # Cytb ML tree
    │   ├── cytb_mcc_named.tree               # Dated BEAST2 tree (MCC)
    │   └── cytb_tip_dating.log               # Сontains the MCMC sampling statistics from the BEAST2 Bayesian dating analysis (open it in Tracer)
    └── reports/
        ├── multiqc_report.html               # Full QC report (interactive)
        └── mapdamage_results/                # KEY mapDamage outputs
            ├── Fragmisincorporation_plot.pdf  # ← C→T damage pattern
            ├── Length_plot.pdf                # ← Fragment length distribution
            ├── 5pCtoT_freq.txt                # C→T frequencies
            ├── 3pGtoA_freq.txt                # G→A frequencies
            ├── lgdistribution.txt             # Length distribution
            ├── Stats_out_MCMC_post_pred.pdf   # MCMC posterior predictive check diagnostics (model fit validation)
            └── Runtime_log.txt                # Run log
               
```

### 🧬 Generated Results Structure (Created Locally)

_Note: These folders are created automatically when you run the scripts._

```text
results/
├── preprocessing/
│   ├── 01_fastp/               # Cleaned reads
│   └── 02_adapterremoval/      # Collapsed reads
├── kraken2_results/            # Classification reports
├── mapping/                    # BAM files, damage plots
├── damage/                       # Full mapDamage output (PDFs, R scripts)
├── mito_mapping/               # Consensus mitogenome assembly
├── mitoz_analysis/             # De novo assembled mitogenomes
└── phylogeny/
    ├── mitogenomes/            # IQ-TREE results (Full/Trimmed)
    └── cytb_analysis/          # ML trees and BEAST2 XMLs/logs
```

---

## 🚀 Quick Start (Usage)

1. **Clone the repository:**

```bash
git clone https://github.com/yourusername/Late_Pleistocene_vole_from_Indigirka_project.git
cd Late_Pleistocene_vole_from_Indigirka_project
```

2. **Make scripts executable (Run once):**

```bash
chmod +x scripts/*.sh
chmod +x scripts/kraken_build/download_kraken.sh
```

3. **Run the pipeline:** Scripts are numbered by execution order. Run them sequentially.

### Tree Visualization

**Reproduce the exact tree figure from the presentation**

Rscript: `scripts/plot_tree_presentation.R`

---

## 🧩 Dependencies

### Option 1: Conda Environment (Recommended)

```bash
# Create environment
conda env create -f environment.yml

# Activate
conda activate late_pleistocene_vole_project
```

### Option 2: Manual Installation

All tools can be installed via [Bioconda](https://bioconda.github.io/):

```bash
conda install -c bioconda fastp adapterremoval kraken2 bwa samtools \
  bcftools picard mapdamage mitoz mafft iqtree clipkit beast2
```

### Python Dependencies

The `rename_tree.py` script uses only Python standard library — no additional packages required.

---

## 🔧 Pipeline Steps

### Step 1: Ancient DNA Preprocessing

**Script:** `scripts/01_preprocess_ancient_dna.sh`

- **Tools:** `fastp`, `AdapterRemoval`
- **Action:** Trims poly-G tails, removes adapters, merges overlapping reads (collapsing).
- **Input:** Raw FASTQ: 115,610,245 paired-end reads (Illumina).
- **Output:** Collapsed FASTQ (~98.2M reads). 

### Step 2: Kraken2 Database & Classification

**Script:** `scripts/02_build_kraken_db.sh`

- **Tools:** `kraken2`, `wget` (custom download script)
- **Action:** Builds a custom database containing NCBI taxonomy, Human genome, Bacteria, Viruses, Fungi, and _Microtus_ references.
- **Note:** Uses `scripts/kraken_build/download_kraken.sh` for reliable downloading of microbial genomes.
- **Output:** Kraken2 index (`kraken2_miurus/`) and classification report.

### Step 3: Mapping & Damage Assessment

**Script:** `scripts/03_map_and_damage.sh`

- **Tools:** `bwa aln`, `samtools`, `picard`, `mapDamage`
- **Action:** Maps reads to reference (optimized for aDNA: `-n 0.04`), marks duplicates, and assesses cytosine deamination patterns.
- **Output:** BAM file, mapDamage plots (confirms authenticity).

### Step 4: Ancient Mitogenome Assembly (Mapping-based)

**Script:** `scripts/04_ancient_mitogenome_assembly.sh`

- **Tools:** `bwa`, `bcftools`
- **Action:** Generates a consensus sequence from mapped reads.
- **Reference:** _M. abbreviatus_ mitogenome.
- **Output:** `consensus.fasta` (Ancient mitogenome), VCF file.

### Step 5: De Novo Mitogenome Assembly (Modern Relatives)

**Script:** `scripts/05_de_novo_mitogenome_assembly.sh`

- **Tools:** `fastq-dump`, `MitoZ` (with MEGAHIT assembler)
- **Action:** Assembles mitogenomes for modern _M. mexicanus_ and _M. oregoni_ from SRA data.
- **Output:** FASTA files for modern reference mitogenomes.

### Step 6: Phylogeny of Microtus Mitogenomes (Main Analysis)

**Script:** `scripts/06_Microtus_mitogenome_phylogeny.sh`

- **Tools:** `mafft`, `iqtree3`
- **Action:** Aligns full mitogenomes (Ancient + Modern + GenBank) and builds a Maximum Likelihood tree.
- **Model:** `GTR+F+I+R3` (selected by ModelFinder).
- **Output:** `mitogenome_tree_full.treefile` (Primary topology).

#### 📊 Data
- **Ingroup:** 25 *Microtus* mitogenomes (22 downloaded from GenBank + 3 newly assembled)
- **Outgroup:** *Arvicola amphibius* (MT381921)
- **Total taxa:** 26

### Step 7: Alternative Phylogeny (Trimmed Alignment)

**Script:** `scripts/07_alternative_Microtus_mitogenome_phylogeny.sh`

- **Tools:** `clipkit`, `iqtree3`
- **Action:** Re-runs phylogeny on a gappy-trimmed alignment to check robustness.
- **Output:** `mitogenome_tree_trimmed.treefile`.

### Step 8: Cytochrome b Tip-Dating (Bayesian)

**Script:** `scripts/08_cytb_tip_dating.sh`

- **Tools:** `BEAST2`, `TreeAnnotator`, `Tracer`, `FigTree`, `rename_tree.py`
- **Action:** Constructs a dated phylogeny using the ancient sample's age (37.7 kya) as a tip calibration.
- **Output:** `cytb_mcc.tree` (Dated tree with HPD intervals).
- **Workflow**: BEAST2 v2.7.7 → Tracer (ESS > 200) → TreeAnnotator → FigTree

#### 📊 Data
- **Gene**: Cytochrome b (cytb), ~1140 bp
- **Taxa**: 67 sequences (62 *M. miurus*, *M. abbreviatus*, outgroups: M. montanus, M. longicaudus, M. ochrogaster, Stenocranius gregalis + ancient Indigirka vole)
- **Ancient sample**: ancient Indigirka vole (37,700 ± 2,200 years BP)
- **Source**: NCBI GenBank (complete cyt b genes with voucher specimens)

### Step 9: Cytochrome b ML Tree (Validation)

**Script:** `scripts/09_cytb_ml_tree.sh`

- **Tools:** `iqtree3`
- **Action:** Builds a standard ML tree for Cytb without dating for topology validation.
- **Output:** `cytb_tree_ml.treefile`.

---

## 📊 Key Results Summary

### Adapter Trimming & Quality Control

- Collapsed FASTQ reads: 98.2M (~85% merge rate)
- Mean length: 128.5 bp (median: 114 bp)
- Quality: Q20 ≥99.78%, Q30 ≥99.12%
- GC content: 55.82%

### Kraken2 Database & Classification

**Database contents:**

- Taxonomy + Human genome
- Bacteria: ~9,000 reference genomes
- Viruses: ~15,041 genomes
- Fungi: ~664 genomes
- Microtus: 4 species

**Classification Results:**

| Category                  | Percentage | Reads     |
| ------------------------- | ---------- | --------- |
| **Classified**            | 65.18%     | 64.0M     |
| **Unclassified**          | 34.82%     | 34.2M     |
| **Microtus (endogenous)** | **34.19%** | **33.6M** |
| └─ To species level       | ~10%       | 10.1M     |
| └─ To genus only          | ~24%       | 23.4M     |
| Bacteria                  | ~29%       | 28.9M     |
| Human contamination       | 0.11%      | 0.1M      |
| Fungi                     | 0.61%      | 0.6M      |


**Kraken taxonomic classification using exact k-mer matches to find the lowest common ancestor (LCA) of a given sequence. Top taxa.**

![kraken_plot](figures/kraken2/kraken-top-n-plot.png)

📄 [multiqc_report.html](results/reports/multiqc_report.html)  
Comprehensive quality control summary including read length distributions, quality scores, adapter content, and taxonomic classification statistics from all preprocessing steps.

### Mapping & Damage Assessment

**Mapping Statistics:**

- Merged reads mapped: 8.68M (8.8% of collapsed)
- Unmerged properly paired: 6,324 (strict filtering)

**Damage Patterns:**

- 5' C→T substitutions: ~3.95% at position 1 (cytosine deamination)
- 3' G→A substitutions: Complementary pattern observed
- Typical aDNA damage profile confirmed

📁 [mapdamage_results/](results/reports/mapdamage_results/)  
Complete ancient DNA authentication data: cytosine deamination patterns (5' C→T and 3' G→A frequencies), fragment length distributions, and MCMC posterior predictive checks confirming authentic aDNA damage signatures.

### Ancient Mitogenome Assembly

**Quality Control Results**

| Metric            | Value                      |
| ----------------- | -------------------------- |
| Mitogenome length | 16295 bp                   |
| Mean coverage     | 73.7×                      |
| Median coverage   | 64.0×                      |
| Covered bases     | 11,530 bp (71%)            |
| N content         | 47.85% (expected for aDNA) |

### De Novo Mitogenome Assembly (Modern Relatives)

| Species        | Length (bp) |
| -------------- | ----------- |
| _M. mexicanus_ | 16,307      |
| _M. oregoni_   | 16,294      |

### Phylogeny of Microtus Mitogenomes

**Best-fit model:** `GTR+F+I+R3` (selected by ModelFinder, BIC criterion)

| Metric     | Full Alignment          | Trimmed (ClipKIT)                   |
| ---------- | ----------------------- | ----------------------------------- |
| Length     | 22,907 bp               | 10,124 bp                           |
| Best Model | GTR+F+I+R3              | TIM2+F+R3                           |
| Topology   | Zoologically consistent | Slight rearrangements in deep nodes |

_Note: The trimmed alignment reduced matrix length from 22,907 bp to 10,124 bp. However, the untrimmed tree yielded a topology more consistent with established _Microtus_ systematics, so it is used as the primary result._

**Ancient Indigirka vole within Microtus mitogenome phylogeny**

![mito_tree](figures/trees/mitogenome_tree.png)

**Conclusion:** The ancient specimen fits reliably into the singing vole clade Microtus miurus with maximum statistical support, which clearly confirms its species affiliation with American voles.

🌳 [mitogenome_tree_full.treefile](results/trees/mitogenome_tree_full.treefile)  
Maximum Likelihood tree based on complete mitogenomes (26 taxa, 22,907 bp, GTR+F+I+R3 model).

### Cytochrome b Phylogeny of *Microtus*

**Best-fit model**: `HKY+F+I+G4` (ModelFinder, BIC)

| Metric                                        | Value                                      |
| --------------------------------------------- | ------------------------------------------ |
| Root Age (_Microtus_)                         | 0.985 Myr [95% HPD: 0.102–1.446]           |
| Ancient Sample Placement                      | Basal sister lineage to modern *M. miurus* |
| Divergence (Ancient + Wrangel vs. Main Clade) | ~0.046–0.559 Myr [95% HPD]                 |
| MCMC Convergence                              | Stable (ESS > 200 for all key parameters)  |

**MCMC Convergence Check (Tracer)**

![Tracer MCMC diagnostics](figures/beast2/tracer_convergence.png)

*All key parameters show ESS > 200, stable trace plots, and unimodal posterior distributions, confirming successful MCMC convergence.*


**Ancient Indigirka vole within Microtus miurus cytb phylogeny** 

![cytb_tree](figures/trees/cytb_dated_tree.png)

**Conclusion:** The 37,700-year-old specimen represents a distinct late Pleistocene lineage sister to modern _M. miurus_, confirming genetic continuity across Beringia and the persistence of ancient haplogroups in isolated refugia (e.g., Wrangel Island).

🌳 [cytb_tree_ml_named.treefile](results/trees/cytb_tree_ml_named.treefile)  
Maximum Likelihood tree from cytochrome b alignment (67 taxa, ~1,140 bp, HKY+F+I+G4 model).

🕐 [cytb_mcc_named.tree](results/trees/cytb_mcc_named.tree)  
Time-calibrated Maximum Clade Credibility (MCC) tree from Bayesian tip-dating analysis. Node ages represent mean estimates with 95% HPD intervals; posterior probabilities indicate clade support.

📊 [cytb_tip_dating.log](results/trees/cytb_tip_dating.log)  
BEAST2 MCMC sampling statistics (20 million generations). Open in Tracer to verify ESS > 200 and inspect posterior distributions of divergence times, clock rates, and tree priors.

---

## 📁 Output Files Guide

Detailed list of key output files:

- **Preprocessing:** `results/preprocessing/02_adapterremoval/02_miurus.collapsed.fastq.gz`
- **Mapping:** `results/mapping/sep_bams/miurus_merged.bam`
- **Consensus:** `results/mito_mapping/03_consensus/consensus.fasta`
- **Trees:**
    - `results/phylogeny/mitogenomes/mitogenome_tree_full.treefile`
    - `results/phylogeny/cytb_analysis/cytb_mcc.tree`

---

## Literature

- Golenishchev, F. N. (2008). The narrow-skulled vole Egorov (Rodentia, Arvicolinae) from the Late Pleistocene of Western Siberia—a North American migrant? Paleontological Journal, 42(2), 193–198. https://doi.org/10.1134/S0031030108020080
- Cole, F. R., & Wilson, D. E. (2010). Microtus miurus (Rodentia: Cricetidae). Mammalian Species, 42(855), 75–89. https://doi.org/10.1644/855.1
- Weksler, M., Lanier, H. C., & Olson, L. E. (2010). Eastern Beringian biogeography: historical and spatial genetic structure of singing voles in Alaska. Journal of Biogeography, 37(8), 1414–1431. https://doi.org/10.1111/j.1365-2699.2010.02310.x
- Lord, E., et al. (2025). Genome analyses suggest recent speciation and postglacial isolation in the Norwegian lemming. Proceedings of the National Academy of Sciences, 122(28), e2424333122. https://doi.org/10.1073/pnas.2424333122
- Chen, S., Zhou, Y., Chen, Y., & Gu, J. (2018). fastp: an ultra-fast all-in-one FASTQ preprocessor. Bioinformatics, 34(17), i884–i890. https://doi.org/10.1093/bioinformatics/bty560
- Schubert, M., Lindgreen, S., & Orlando, L. (2016). AdapterRemoval v2: rapid adapter trimming, identification, and read merging. BMC Research Notes, 9, 88. https://doi.org/10.1186/s13104-016-1900-2
- Wood, D. E., Lu, J., & Langmead, B. (2019). Improved metagenomic analysis with Kraken 2. Genome Biology, 20, 257. https://doi.org/10.1186/s13059-019-1891-0
- Jónsson, H., Ginolhac, A., Schubert, M., Johnson, P. L., & Orlando, L. (2013). mapDamage2.0: fast approximate Bayesian estimates of ancient DNA damage parameters. Bioinformatics, 29(13), 1682–1684. https://doi.org/10.1093/bioinformatics/btt193
- Briggs, A. W., et al. (2007). Patterns of damage in genomic DNA sequences from a Neandertal. Proceedings of the National Academy of Sciences, 104(37), 14616–14621. https://doi.org/10.1073/pnas.0704665104
- Li, H., & Durbin, R. (2009). Fast and accurate short read alignment with Burrows–Wheeler transform. Bioinformatics, 25(14), 1754–1760. https://doi.org/10.1093/bioinformatics/btp324
- Minh, B. Q., et al. (2020). IQ-TREE 2: new models and efficient methods for phylogenetic inference in the genomic era. Molecular Biology and Evolution, 37(5), 1530–1534. https://doi.org/10.1093/molbev/msaa015
- Bouckaert, R., et al. (2019). BEAST 2.5: an advanced software platform for Bayesian evolutionary analysis. PLOS Computational Biology, 15(4), e1006650. https://doi.org/10.1371/journal.pcbi.1006650
- De Jong, M. J., et al. (2023). Range-wide whole-genome resequencing of the brown bear reveals drivers of intraspecies divergence. Communications Biology, 6(1), 153. https://doi.org/10.1038/s42003-023-04514-w
- Meng, G., Li, Y., Yang, C., & Liu, S. (2019). MitoZ: a toolkit for animal mitochondrial genome assembly, annotation and visualization. Nucleic acids research, 47(11), e63. https://doi.org/10.1093/nar/gkz173.
- Danecek P, Bonfield JK, Liddle J, Marshall J, Ohan V, Pollard MO, Whitwham A, Keane T, McCarthy SA, Davies RM, Li H. Twelve years of SAMtools and BCFtools. GigaScience. 2021;10(2):giab008. doi:10.1093/gigascience/giab008

---

**Authors:** Natalia Laskina, Liliya Revyakina  

**Year:** 2026