library(ggtree)

tree <- read.tree("mitogenome_tree_full.treefile")

p <- ggtree(tree) +
  geom_tree() +
  geom_treescale() +
  xlim(0, 0.7)

p <- p + geom_nodelab(size = 5, fontface = "bold", hjust = 0, color = "black")

p <- p + geom_tiplab(
  data = subset(p$data, label != "ancient_Indigirka_vole"),
  color = "black",
  size = 6,
  fontface = "bold",
  offset = 0.02
)

p <- p + geom_tiplab(
  data = subset(p$data, label == "ancient_Indigirka_vole"),
  color = "red",
  size = 7,
  fontface = "bold",
  offset = 0.02
)

print(p)

ggsave("mitogenome_tree.png", plot = p, width = 14, height = 10, dpi = 300)
