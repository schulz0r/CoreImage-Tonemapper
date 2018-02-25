# CoreImage-Tonemapper
A TMO with local contrast enhancement implemented as a CIImageProcessorKernel.

This tonemapper first segments the image into regions of similar brightness with C-Means clustering. Then, each region will be tonemapped independently with parameters obtained exclusively from the respective region. To avoid seams between the zones, and image pyramid blending algorithm will be used to merge all regions into an tonemapped image. This will be the output of the first stage of the tonemapping operator (TMO).
In the second stage, local contrasts will be restored by an iterative approach.

Literature (so far)

Banterle, Francesco, et al. "Mixing tone mapping operators on the GPU by differential zone mapping based on psychophysical experiments." Signal Processing: Image Communication 48 (2016): 50-62.

