# Directory for auxiliary files (hidden)
$aux_dir = '.latex-build';

# Output directory for PDF (root directory)
$out_dir = '.';

# Ensure the build directory exists
system("mkdir -p .latex-build");

# PDF generation mode (1 = pdflatex)
$pdf_mode = 1;

# Use biber for bibliography
$biber = 'biber %O %S';
$bibtex_use = 2;
