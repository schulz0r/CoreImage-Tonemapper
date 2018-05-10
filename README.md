# CoreImage-Tonemapper

# Please note that this project is still W.I.P. and is not complete yet

A tonemapping operator (TMO) with local contrast enhancement implemented as a CIImageProcessorKernel. It's key feature is the segmentation of the HDR image, wich enables the algorithm to tweak the tonemapping parameters for different parts of the image.

The tonemapper first segments the image into regions of similar brightness with K-Means clustering. This results in three clusters and a label map which assigns each pixel of the image to a cluster. Then, multiple tonemaps will be generated, each using a different parametrization obtained from a image segment. To avoid seams between the zones, an image pyramid blending algorithm will be employed to merge all regions into a tonemapped image. This will be the output of the first stage of the tonemapping operator (TMO).
In the second stage, local contrasts will be restored by an iterative approach.

Literature (so far)

Banterle, Francesco, et al. "Mixing tone mapping operators on the GPU by differential zone mapping based on psychophysical experiments." Signal Processing: Image Communication 48 (2016): 50-62.

Ferradans, S., & Caselles, V. (2009). TSTM: A Two-Stage Tone Mapper Combining Visual Adaptation and Local Contrast Enhancement, 1–11. Retrieved from papers://b6c7d293-c492-48a4-91d5-8fae456be1fa/Paper/p12868%5Cnfile:///C:/Users/Serguei/OneDrive/Documents/Papers/TSTM A Two-Stage Tone Mapper-2009-05-08.pdf
