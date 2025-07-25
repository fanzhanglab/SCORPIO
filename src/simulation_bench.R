# Access command-line arguments
args <- commandArgs(trailingOnly = TRUE)

# Check if any arguments are provided
if (length(args) == 0) {
  stop("No arguments provided. Usage: Rscript my_script.R <arg1> <arg2>")
}

# Extract command-line parameters
num_samples <- as.numeric(args[1])
fold_change <- as.numeric(args[2])

source("./simulation_functions.R")

n_thread=4
registerDoParallel(cores = n_thread)
current_dir <- getwd()
results_path <- file.path(current_dir, "results")
data_path <- file.path(current_dir, "data")
# Create the folders if they don't exist
if (!dir.exists(results_dir)) {
  dir.create(results_dir)
}
if (!dir.exists(data_dir)) {
  dir.create(data_dir)
}

# parameters for generating dummy dataset
n_cells=100 # cells per individual #PER CELLTYPE
sd_celltypes=0.1  # standard deviation of number of cells 
n_major_cell_types=7
n_minor_cell_types=3
relative_abundance=0.4 # ratio between major and rare
n_major_diff_celltypes=1
n_minor_diff_celltypes=1
n_individuals=num_samples # total individuals
n_batchs=4
prop_sex=0.5 # proportion of feature 1 if feature 1 is categorical variable
prop_disease=0.5  # proportion of feature 2 if feature 2 is categorical variable
# interaction_feature_1="sex"
# interaction_feature_2="disease"
# interaction_feature_1="age"
# interaction_feature_2="bmi"
fc_increase=fold_change # proportion of interacted cells which are from people with interacted group
# interaction_type="specific" # c("specific","differential","opposite")
seed=1234
n_features = 1000
cluster_features = 1:200
disease_features = 1:200
sex_features = 1:200 # seq(2, 20, by = 2)
age_features = 1:200 # seq(2, 10, by = 2)
bmi_features = 1:200 # seq(11, 20, by = 2)
batch_features = 1:200 # seq(1, 20,by = 2)
individual_features = 1:200 # seq(1, 20,by = 2)

# Define the maximum variance in features of each attribute
cluster_ratio = 0.7
disease_ratio = 0.05
sex_ratio = 0.05 # 0.05
age_ratio = 0.05 # 0.05
bmi_ratio = 0.05 # 0.05
batch_ratio = 0.05 # 0.1
individual_ratio = 0.05 # 0.1

n_pcs = 20

ratio_variance = 0.1

cluster_col = "cell_type"
sex_col = "sex"
age_col = "age"
bmi_col = "bmi"
batch_col = "batch"
disease_col = "disease"
individual_col = 'subject_id'

# parameters for UMAP
n_neighbors = 30
metric = "cosine"
min_dist = 0.01

# downsampling parameter for MASC to save time(1 means no downsampling)
ds_pro = 1 

# parameters for CNA
test_var="condition_val"
samplem_key = 'subject_id'
graph_use = 'RNA_nn'
batches = "batch"

nsteps = NULL
verbose=TRUE
assay=NULL
key='NAMPC_'
maxnsteps=15L
max_frac_pcs=0.15
ks=NULL
Nnull=1000
force_permute_all=FALSE
local_test=TRUE
return_nam=TRUE



dummy_data <- generate_dummy_data_woInteraction(n_cells = n_cells, # cells per individual
                                                sd_celltypes = sd_celltypes,  # standard deviation of number of cells 
                                                n_major_cell_types = n_major_cell_types,
                                                n_minor_cell_types = n_minor_cell_types,
                                                relative_abundance = relative_abundance, # ratio between major and rare
                                                n_major_diff_celltypes = n_major_diff_celltypes,
                                                n_minor_diff_celltypes = n_minor_diff_celltypes,
                                                
                                                n_individuals = n_individuals, # total individuals
                                                n_batchs = n_batchs,
                                                prop_sex = prop_sex, # proportion of feature 1 if feature 1 is categorical variable
                                                prop_disease = prop_disease,  # proportion of feature 2 if feature 2 is categorical variable
                                                fc_interact = fc_increase, # additional FC of specified cell types which are from people with case groups compared to control groups (e.g., if you specify 0.5, FC comparing increased cell type between case and control groups will be 1.5 in total)
                                                seed = seed
)
diff_cell_types = dummy_data[[2]]
dummy_data = dummy_data[[1]]

pseudo_feature_matrix <- generate_pseudo_features(dummy_data, 
                                                  n_features = n_features, 
                                                  cluster_features = cluster_features,
                                                  disease_features = disease_features,
                                                  sex_features = sex_features, 
                                                  age_features = age_features,
                                                  bmi_features = bmi_features,
                                                  batch_features = batch_features,
                                                  individual_features = individual_features,
                                                  
                                                  # Define the maximum percentage of each attribute
                                                  cluster_ratio = cluster_ratio,
                                                  disease_ratio = disease_ratio,
                                                  sex_ratio = sex_ratio,
                                                  age_ratio = age_ratio,
                                                  bmi_ratio = bmi_ratio,
                                                  batch_ratio = batch_ratio,
                                                  individual_ratio = individual_ratio,
                                                  
                                                  ratio_variance = ratio_variance,
                                                  
                                                  cluster_col = cluster_col,
                                                  sex_col = sex_col,
                                                  age_col = age_col,
                                                  bmi_col = bmi_col,
                                                  batch_col = batch_col,
                                                  disease_col = disease_col,
                                                  individual_col = individual_col,
                                                  seed = seed,
                                                  
                                                  n_thread = 4,
                                                  verbose = TRUE
)
colnames(pseudo_feature_matrix) <- paste0("Feature", 1:ncol(pseudo_feature_matrix))


pseudo_pcs_matrix_res <- irlba::prcomp_irlba(pseudo_feature_matrix, n_pcs, maxit = 3000)
pseudo_pcs_matrix_res$sdev^2 / sum(pseudo_pcs_matrix_res$sdev^2)
pseudo_pcs_matrix = pseudo_pcs_matrix_res$x
colnames(pseudo_pcs_matrix) <- paste0("PC", 1:ncol(pseudo_pcs_matrix))


dummy_data_with_pcs <- cbind(dummy_data, pseudo_pcs_matrix)


options(repr.plot.height = 10, repr.plot.width = 12)
cluster_center <- dummy_data_with_pcs %>%
  dplyr::group_by(cell_type) %>%
  dplyr::summarise_at(vars(PC1, PC2), dplyr::funs(median(., na.rm=TRUE)))
cluster_center <- as.data.frame(cluster_center)
ggplot() +
  geom_point(
    data = dummy_data_with_pcs,
    mapping = aes_string(x = "PC1", y = "PC2", color = "cell_type"),
    size = 1, stroke = 0, shape = 16,alpha = 0.5
  ) +
  geom_label_repel(
    data = cluster_center,
    aes(x = PC1, y = PC2, label = cell_type, fill = cell_type),
    color = "white",segment.color = "black",
    size = 7,
    min.segment.length = 0, seed = 42, box.padding = 0.8,
    max.overlaps = Inf
  ) +
  labs(
    x = "PC1",
    y = "PC2",
    title = ""
  ) +
  coord_fixed(ratio = 1) +
  theme_bw(base_size = 20) +
  theme(
    legend.position = "none",
    axis.text = element_blank(),
    axis.ticks = element_blank(),
    panel.grid = element_blank(),
    plot.title = element_text(color="black", size=10)
  )
ggsave(paste0("sim_", 
              "fc", fold_change, 
              "_num_samples",num_samples, 
              "_pcplot.pdf"),
       plot = last_plot(),device = "pdf",path = results_path, width= 50, height = 20, units = "cm", dpi = 500)




#UMAP
umap_res <- uwot::umap(pseudo_pcs_matrix, 
                       n_neighbors = n_neighbors, 
                       metric = "cosine", 
                       min_dist = min_dist, 
                       n_threads = n_thread)
umap_res = umap_res %>% 
  magrittr::set_colnames(c("UMAP1","UMAP2")) %>%
  as.data.frame()

dummy_data_with_umap <- cbind(dummy_data, umap_res)



dummy_data$condition_val = as.numeric(dummy_data[,disease_col])

nam_res = association_nam(seurat_object=NULL,
                          metadata=dummy_data,
                          pcs=pseudo_pcs_matrix,
                          test_var=test_var,
                          samplem_key = samplem_key,
                          graph_use = graph_use,
                          batches = batches,
                          covs = c(age_col,sex_col),
                          nsteps = nsteps,
                          verbose=verbose,
                          assay=assay,
                          key=key,
                          maxnsteps=maxnsteps,
                          max_frac_pcs=max_frac_pcs, # added option to pass number of PCs, for potential speedups
                          ks=ks,
                          Nnull=Nnull,
                          force_permute_all=force_permute_all,
                          local_test=local_test,
                          seed=seed,
                          return_nam=return_nam
)

options(repr.plot.height = 30, repr.plot.width = 18)
g0 = dummy_data %>%
  dplyr::group_by(subject_id,sex,disease,cell_type) %>%
  dplyr::summarise(count = dplyr::n()) %>%
  dplyr::group_by(subject_id,sex,disease) %>%
  dplyr::mutate(proportion = 100*count/sum(count),
                sex_label = ifelse(sex=="0","Male","Female"),
                disease_label = ifelse(disease=="0","Control","Disease")) %>%
  ggplot(.,aes(x=disease_label,y=proportion,color = disease_label)) +
  geom_boxplot() +
  geom_point(position=position_jitterdodge(0.9)) +
  ggpubr::stat_compare_means(comparisons = list(c("Control","Disease")), 
                             label = "{p.adj}{p.adj.signif}", method = "wilcox.test", label.y.npc = 0.4, tip.length = 0) +
  scale_color_manual(values = c(
    "Control" = "#4DAF4A",
    "Disease" = "#984EA3")) +
  ggh4x::facet_nested_wrap(vars(cell_type), nrow = 1) +
  theme_classic() +
  theme(strip.text.x=element_text(size=15, color="black"),
        strip.text.y=element_text(size=15, color="black"),
        strip.placement = "outside", 
        strip.background.x=element_rect(color = NA,  fill=NA), 
        strip.background.y=element_rect(color = "black",  fill=NA),
        legend.position = "right",
        plot.title = element_text(size=15),
        axis.title.x = element_text(size=15),
        axis.title.y = element_text(size =15),
        axis.text.y = element_text(size = 15),
        axis.text.x = element_text(size = 15, angle = 45, hjust = 1),
        legend.text =  element_text(size = 15),
        legend.key.size = grid::unit(0.5, "lines"),
        legend.title = element_text(size = 0.8, hjust = 0)) +
  labs(
    x = "Disease status",
    y = "Proportion (%)",
    title = ""
  )  


g1 = dummy_data %>%
  dplyr::group_by(subject_id,sex,disease,cell_type) %>%
  dplyr::summarise(count = dplyr::n()) %>%
  dplyr::group_by(subject_id,sex,disease) %>%
  dplyr::mutate(proportion = 100*count/sum(count),
                sex_label = ifelse(sex=="0","Male","Female"),
                disease_label = ifelse(disease=="0","Control","Disease")) %>%
  ggplot(.,aes(x=disease_label,y=proportion,color = disease_label)) +
  geom_boxplot() +
  geom_point(position=position_jitterdodge(0.9)) +
  ggpubr::stat_compare_means(comparisons = list(c("Control","Disease")), 
                             label = "{p.adj}{p.adj.signif}", method = "wilcox.test", label.y.npc = 0.4, tip.length = 0) +
  scale_color_manual(values = c(
    "Control" = "#4DAF4A",
    "Disease" = "#984EA3")) +
  ggh4x::facet_nested_wrap(vars(cell_type, sex_label), nrow = 1) +
  theme_classic() +
  theme(strip.text.x=element_text(size=15, color="black"),
        strip.text.y=element_text(size=15, color="black"),
        strip.placement = "outside", 
        strip.background.x=element_rect(color = NA,  fill=NA), 
        strip.background.y=element_rect(color = "black",  fill=NA),
        legend.position = "right",
        plot.title = element_text(size=15),
        axis.title.x = element_text(size=15),
        axis.title.y = element_text(size =15),
        axis.text.y = element_text(size = 15),
        axis.text.x = element_text(size = 15, angle = 45, hjust = 1),
        legend.text =  element_text(size = 15),
        legend.key.size = grid::unit(0.5, "lines"),
        legend.title = element_text(size = 0.8, hjust = 0)) +
  labs(
    x = "Disease status",
    y = "Proportion (%)",
    title = ""
  )  


cluster_center <- data.frame(dummy_data, umap_res) %>%
  dplyr::group_by(cell_type) %>%
  dplyr::summarise_at(vars(UMAP1, UMAP2), dplyr::funs(median(., na.rm=TRUE)))
cluster_center <- as.data.frame(cluster_center)
g2 = ggplot() +
  geom_point(
    data = data.frame(dummy_data, umap_res),
    mapping = aes_string(x = "UMAP1", y = "UMAP2", color = "cell_type"),
    size = 1, stroke = 0, shape = 16,alpha = 0.3
  ) +
  geom_label_repel(
    data = cluster_center,
    aes(x = UMAP1, y = UMAP2, label = cell_type, fill = cell_type),
    color = "white",segment.color = "black",
    size = 7,
    min.segment.length = 0, seed = 42, box.padding = 0.8,
    max.overlaps = Inf
  ) +
  labs(
    x = "UMAP1",
    y = "UMAP2",
    title = ""
  ) +
  coord_fixed(ratio = 1.2) +
  theme_classic() +
  theme(strip.text.x=element_text(size=15, color="black"),
        strip.text.y=element_text(size=15, color="black"),
        strip.placement = "outside", 
        strip.background.x=element_rect(color = NA,  fill=NA), 
        strip.background.y=element_rect(color = "black",  fill=NA),
        legend.position = "none",
        plot.title = element_text(size=15),
        axis.title.x = element_text(size=15),
        axis.title.y = element_text(size =15),
        axis.text.y = element_text(size = 15),
        axis.text.x = element_text(size = 15),
        legend.text =  element_text(size = 10),
        legend.key.size = grid::unit(0.5, "lines"),
        legend.title = element_text(size = 10, hjust = 0))

g3 = 
  data.frame(dummy_data_with_umap[,c("UMAP1","UMAP2")], ncorrs = nam_res@meta.data$cna_ncorrs_fdr05) %>%
  ggplot() +
  geom_point(aes(x = UMAP1, y = UMAP2, color = ncorrs, alpha = abs(ncorrs)), size = 0.01) +
  scale_color_gradient2(midpoint = 0, low = '#3C5488FF', mid = "grey90", high = '#DC0000FF', space = "Lab" ) +
  labs(
    x = "UMAP1",
    y = "UMAP2",
    title = paste0("Disease association\n",sprintf("global p=%0.3f",nam_res@reductions$cna@misc$p)," [Filtered for FDR<0.05]"), 
    color = paste0("correlation"),
    alpha = paste0("correlation")
  ) +
  coord_fixed(ratio = 1.2) +
  theme_classic() +
  theme(strip.text.x=element_text(size=15, color="black"),
        strip.text.y=element_text(size=15, color="black"),
        strip.placement = "outside", 
        strip.background.x=element_rect(color = NA,  fill=NA), 
        strip.background.y=element_rect(color = "black",  fill=NA),
        legend.position = "right",
        plot.title = element_text(size=15),
        axis.title.x = element_text(size=15),
        axis.title.y = element_text(size =15),
        axis.text.y = element_text(size = 15),
        axis.text.x = element_text(size = 15),
        legend.text =  element_text(size = 10),
        legend.key.size = grid::unit(0.5, "lines"),
        legend.title = element_text(size = 10, hjust = 0))

cor_pos = nam_res@meta.data$cna_ncorrs_fdr05
cor_pos = cor_pos[cor_pos > 0]
# summary(cor_pos)
cor_neg = nam_res@meta.data$cna_ncorrs_fdr05
cor_neg = cor_neg[cor_neg < 0]
# summary(cor_neg)
ord = sort(unique(dummy_data$cell_type))
p_ <- data.frame(dummy_data_with_umap[,c("UMAP1","UMAP2")], ncorrs = nam_res[["cna"]]@misc$ncorrs, res_cell = dummy_data$cell_type) %>%
  dplyr::mutate(res_cell = factor(res_cell,levels=ord)) %>%
  ggplot(aes(x=res_cell, y=ncorrs)) + 
  geom_violin(trim=TRUE, scale = "width")
mywidth <- .35 # bit of trial and error
# This is all you need for the fill: 
vl_fill <- data.frame(ggplot_build(p_)$data) %>%
  mutate(xnew = x- mywidth*violinwidth, xend = x+ mywidth*violinwidth) 
# Bit convoluted for the outline, need to be rearranged: the order matters
vl_poly <- 
  vl_fill %>% 
  dplyr::select(xnew, xend, y, group) %>%
  pivot_longer(-c(y, group), names_to = "oldx", values_to = "x") %>% 
  arrange(y) %>%
  split(., .$oldx) %>%
  map(., function(x) {
    if(all(x$oldx == "xnew")) x <- arrange(x, desc(y))
    x
  }) %>%
  bind_rows()
g4 = ggplot() +
  geom_polygon(data = vl_poly, aes(x, y, group = group), size = 1, fill = NA) +  
  geom_segment(data = vl_fill, aes(x = xnew, xend = xend, y = y, yend = y, color = y)) +
  scale_color_gradient2(midpoint = 0, low = '#3C5488FF', mid = "white", high = '#DC0000FF', space = "Lab") +
  scale_x_continuous(labels=ord, breaks=1:length(unique(ord)) , limits=c(min(vl_poly$x),max(vl_poly$x))) +
  geom_hline(yintercept=0, linetype='dashed', color='black') +
  geom_hline(yintercept=c(min(cor_pos), max(cor_neg)), linetype='dotted', color='grey45') +
  theme_classic() +
  coord_flip() +
  theme(strip.text.x=element_text(size=15, color="black", face="bold"),
        strip.text.y=element_text(size=15, color="black", face="bold"),
        legend.position = "none",
        plot.title = element_text(size=15),
        axis.title.x = element_text(size=15),
        axis.title.y = element_text(size =15),
        axis.text.y = element_text(size =15),
        axis.text.x = element_text(size =15),
        legend.text =  element_text(size = 15),
        legend.key.size = grid::unit(0.5, "lines"),
        legend.title = element_text(size = 0.8, hjust = 0)) +
  labs(title = "",
       x = "",
       y = "Neighborhood\nCorrelation") 

ord = c(paste0(rep(sort(unique(dummy_data$cell_type)),each=2),c(".Female",".Male")))
p_ <- data.frame(dummy_data_with_umap[,c("UMAP1","UMAP2")], ncorrs = nam_res@meta.data$cna_ncorrs, res_cell = dummy_data[,cluster_col], sex = ifelse(dummy_data[,sex_col]==1, "Female", "Male")) %>%
  dplyr::mutate(new_x = interaction(res_cell, sex),
                new_x = factor(new_x, levels=ord)) %>%
  ggplot(aes(x=new_x, y=ncorrs)) + 
  geom_violin(trim=TRUE, scale = "width") +
  scale_color_gradient2(midpoint = 0, low = '#3C5488FF', mid = "white", high = '#DC0000FF', space = "Lab")
mywidth <- .35 # bit of trial and error
# This is all you need for the fill: 
vl_fill <- data.frame(ggplot_build(p_)$data) %>%
  mutate(xnew = x- mywidth*violinwidth, xend = x+ mywidth*violinwidth) 
# Bit convoluted for the outline, need to be rearranged: the order matters
vl_poly <- 
  vl_fill %>% 
  dplyr::select(xnew, xend, y, group) %>%
  pivot_longer(-c(y, group), names_to = "oldx", values_to = "x") %>% 
  arrange(y) %>%
  split(., .$oldx) %>%
  map(., function(x) {
    if(all(x$oldx == "xnew")) x <- arrange(x, desc(y))
    x
  }) %>%
  bind_rows()
g5 =  ggplot() +
  geom_polygon(data = vl_poly, aes(x, y, group = group), size = 1, fill = NA) +  
  geom_segment(data = vl_fill, aes(x = xnew, xend = xend, y = y, yend = y, color = y)) +
  scale_color_gradient2(midpoint = 0, low = '#3C5488FF', mid = "white", high = '#DC0000FF', space = "Lab") +
  scale_x_continuous(labels=ord, breaks=1:length(ord) , limits=c(min(vl_poly$x),max(vl_poly$x))) +
  geom_hline(yintercept=0, linetype='dashed', color='black') +
  geom_hline(yintercept=c(min(cor_pos), max(cor_neg)), linetype='dotted', color='grey45') +
  theme_classic() +
  coord_flip() +
  theme(strip.text.x=element_text(size=15, color="black", face="bold"),
        strip.text.y=element_text(size=15, color="black", face="bold"),
        legend.position = "none",
        plot.title = element_text(size=15),
        axis.title.x = element_text(size=15),
        axis.title.y = element_text(size =15),
        axis.text.y = element_text(size =12),
        axis.text.x = element_text(size =15),
        legend.text =  element_text(size = 15),
        legend.key.size = grid::unit(0.5, "lines"),
        legend.title = element_text(size = 0.8, hjust = 0)) +
  labs(title = "",
       x = "",
       y = "Neighborhood\nCorrelation") 


(g0) / 
(g1) / 
  (g2 + g3 ) / 
  ((g4 + g5 ) + patchwork::plot_layout(nrow = 1, heights = c(1, 1, 1, 0.1)))
ggsave(paste0("sim_", 
              "fc", fold_change, 
              "_num_samples",num_samples, 
              "_umap_cna.pdf"),
       plot = last_plot(),device = "pdf",path = results_path, width= 30, height = 65, units = "cm", dpi = 500)


harmonized_NAM <- RunHarmony(nam_res@reductions$cna@misc$NAM_embeddings, dummy_data, c("subject_id", "batch"))
dummy_data_NAM_harmonized <- cbind(dummy_data, harmonized_NAM)


options(repr.plot.height = 10, repr.plot.width = 40)
dummy_data_NAM_harmonized %>%
  dplyr::select(disease, starts_with("PC")) %>%
  pivot_longer(!disease, names_to = "PC", values_to = "value") %>%
  dplyr::mutate(PC = factor(PC, levels=paste0("PC",1:20))) %>%
  ggplot(., aes(x = value, y = disease)) +
  ggridges::geom_density_ridges(aes(fill = disease, color = disease), scale = 1) +
  facet_wrap(PC ~ ., ncol = 10, scales = "free") +
  theme_classic(base_size=40) + # aspect.ratio = 0.75, 
  theme(strip.text.x=element_text(size=40, color="black", face="bold"), 
        strip.text.y=element_text(size=40, color="black", face="bold"),
        legend.position = "right",
        plot.title = element_text(size=40, color="black"),
        axis.title.x = element_text(size=40, color="black"),
        axis.title.y = element_text(size =40, color="black"),
        axis.text.y = element_text(size = 40, color="black"),
        axis.text.x = element_text(size = 30, color="black", angle = 45, hjust = 1),
        legend.text =  element_text(size = 40, color="black"),
        legend.key.size = grid::unit(1.75, "lines"),
        legend.title = element_text(size = 40, hjust = 0, color="black")) +
  labs(title = "PC Distribution by Disease (harmonized PCs)",
       x = "loadings",
       y = "disease")
ggsave(paste0("sim_", 
              "fc", fold_change, 
              "_num_samples",num_samples,
              "_diseasedist.pdf"),
       plot = last_plot(),device = "pdf",path = results_path, width= 80, height = 20, units = "cm", dpi = 500)

options(repr.plot.height = 6, repr.plot.width = 30)
dummy_data_NAM_harmonized %>%
  dplyr::select(cell_type, starts_with("PC")) %>%
  pivot_longer(!cell_type, names_to = "PC", values_to = "value") %>%
  dplyr::mutate(PC = factor(PC, levels=paste0("PC",1:20))) %>%
  ggplot(., aes(x = value, y = cell_type)) +
  ggridges::geom_density_ridges(aes(fill = cell_type, color = cell_type), scale = 1) +
  facet_wrap(PC ~ ., ncol = 10, scales = "free") +
  theme_classic() +
  theme(strip.text.x=element_text(size=15, color="black", face="bold"),
        strip.text.y=element_text(size=15, color="black", face="bold"),
        legend.position = "none",
        plot.title = element_text(size=15),
        axis.title.x = element_text(size=15),
        axis.title.y = element_text(size =15),
        axis.text.y = element_text(size = 20),
        axis.text.x = element_text(size = 15),
        legend.text =  element_text(size = 15),
        legend.key.size = grid::unit(0.5, "lines"),
        legend.title = element_text(size = 0.8, hjust = 0)) +
  labs(title = "PC Distribution by Cell Type (harmonized PCs)",
       x = "loadings",
       y = "cell_type")
ggsave(paste0("sim_", 
              "fc", fold_change, 
              "_num_samples",num_samples,
              "_celltypedist.pdf"),
       plot = last_plot(),device = "pdf",path = results_path, width= 70, height = 35, units = "cm", dpi = 500)

# Anova
fit = lm(PC1 ~ cell_type + subject_id + sex + disease + age + batch + bmi, data = dummy_data_NAM_harmonized)
#summary(fit)

af <- anova(fit)
afss <- af$"Sum Sq"

res_1 <- cbind(af,PctExp=afss/sum(afss)*100)
res_1$variable <- rownames(res_1)

res_1$variable[which(res_1$variable == "sex")] <- "Sex"
res_1$variable[which(res_1$variable == "subject_id")] <- "Subject ID"
res_1$variable[which(res_1$variable == "age")] <- "Age"
res_1$variable[which(res_1$variable == "batch")] <- "Batch"
res_1$variable[which(res_1$variable == "bmi")] <- "BMI"
res_1$variable[which(res_1$variable == "cell_type")] <- "Cell Type"
options(repr.plot.height = 2.5, repr.plot.width = 5)
ggplot(data=res_1, aes(x=reorder(variable, -PctExp), y=PctExp)) +
  geom_bar(stat="identity", width = 0.7) +
  coord_flip() +
  labs(x = "", y = paste("% variance explained in\nHarmonized NAM PC1\nfc_increase = ", fc_increase)) +
  scale_y_continuous(limits = c(0, 100)) +
  theme_classic(base_size = 15) +
  theme(
    legend.position = "none",
#     axis.text = element_blank(),
#     axis.ticks = element_blank(),
    axis.text.x = element_text(color = "black"),
    axis.text.y = element_text(color = "black"),
    panel.grid = element_blank()
  )
ggsave(paste0("sim_", 
              "fc", fold_change, 
              "_num_samples",num_samples,
              "_pc1varexp.pdf"),
       plot = last_plot(),device = "pdf",path = results_path, width = 5, height = 2.5, dpi = 500)

save data lol
nam_file_name = paste0(data_path,
                    "simulated_pc_NAM_HARMONIZED_jade_woi_advanced",
                    "_numCell", n_cells,
                    "_numSamp", n_individuals,
                    "_sd", sd_celltypes,
                    "_fci", fc_increase,
                    "_clusterRatio", cluster_ratio,
                    "_diseaseRatio", disease_ratio,
                    ".csv")
write.csv(harmonized_NAM, file=nam_file_name, row.names=FALSE, col.names=TRUE)

meta_file_name = paste0(data_path,
                    "simulated_umap_data_jade_woi_advanced",
                    "_numCell", n_cells,
                    "_numSamp", n_individuals,
                    "_sd", sd_celltypes,
                    "_fci", fc_increase,
                    "_clusterRatio", cluster_ratio,
                    "_diseaseRatio", disease_ratio,
                    ".csv")
write.csv(dummy_data_with_umap, file=meta_file_name, row.names=FALSE, col.names=TRUE)

file_name = paste0(data_path,
                    "simulated_cna_data_jade_woi_advanced",
                    "_numCell", n_cells,
                    "_numSamp", n_individuals,
                    "_sd", sd_celltypes,
                    "_fci", fc_increase,
                    "_clusterRatio", cluster_ratio,
                    "_diseaseRatio", disease_ratio,
                    ".csv")
write.csv(nam_res@meta.data$cna_ncorrs_fdr05, file=file_name, row.names=FALSE, col.names=TRUE)
