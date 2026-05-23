library(ggtree)
library(tidyverse)

tree <- read.tree("mitogenome_tree_full.treefile")

p <- ggtree(tree) + xlim(0, 0.7)

node_data <- p$data %>%
  filter(!isTip, !is.na(label)) %>%
  mutate(label_str = as.character(label)) %>%
  separate(label_str, into = c("sup1", "sup2", "sup3"), sep = "/", convert = TRUE, extra = "drop", fill = "right")

node_data <- node_data %>%
  mutate(
    sup1_final = sup1,
    sup2_final = ifelse(!is.na(sup2) & sup2 <= 1, sup2 * 100, sup2),
    sup3_final = ifelse(!is.na(sup3) & sup3 <= 1, sup3 * 100, sup3)
  )

points_list <- list()

if(nrow(node_data %>% filter(!is.na(sup1_final) & sup1_final > 95)) > 0) {
  df_b <- node_data %>%
    filter(!is.na(sup1_final) & sup1_final > 95) %>%
    mutate(metric = "Bootstrap", x_plot = x - 0.01)
  points_list[[1]] <- df_b
}

if(nrow(node_data %>% filter(!is.na(sup2_final) & sup2_final > 95)) > 0) {
  df_alrt <- node_data %>%
    filter(!is.na(sup2_final) & sup2_final > 95) %>%
    mutate(metric = "aLRT", x_plot = x)
  points_list[[2]] <- df_alrt
}

if(nrow(node_data %>% filter(!is.na(sup3_final) & sup3_final > 95)) > 0) {
  df_abayes <- node_data %>%
    filter(!is.na(sup3_final) & sup3_final > 95) %>%
    mutate(metric = "aBayes", x_plot = x + 0.01)
  points_list[[3]] <- df_abayes
}

if(length(points_list) > 0) {
  all_points <- bind_rows(points_list)
  
  p <- p + geom_point(
    data = all_points,
    aes(x = x_plot, y = y, shape = metric, color = metric),
    size = 3
  ) +
    scale_shape_manual(
      values = c("Bootstrap" = 16, "aLRT" = 17, "aBayes" = 15),
      name = "Support"
    ) +
    scale_color_manual(
      values = c("Bootstrap" = "orange", "aLRT" = "purple", "aBayes" = "darkblue"),
      name = "Support"
    ) +
    theme(legend.position = "top")
}

p <- p + geom_tiplab(
  data = subset(p$data, label != "ancient_Indigirka_vole"),
  color = "black", size = 6, fontface = "bold", offset = 0.02
)

p <- p + geom_tiplab(
  data = subset(p$data, label == "ancient_Indigirka_vole"),
  color = "red", size = 7, fontface = "bold", offset = 0.02
)

print(p)
ggsave("mitogenome_tree.png", plot = p, width = 14, height = 10, dpi = 300)
