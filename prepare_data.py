import numpy as np
import conv2d as conv
import struct
import matplotlib.pyplot as plt
import random


# Load MNIST image data
def load_mnist_images(filename):
    with open(filename, "rb") as f:
        _, num_images = struct.unpack(">II", f.read(8))
        rows, cols = struct.unpack(">II", f.read(8))
        raw_data = np.fromfile(f, dtype=np.uint8)
        return raw_data.reshape((num_images, rows, cols))


# Save matrix to 8-bit hex format
def save_hex_file(filename, matrix):
    hex_format = np.vectorize(lambda x: f"{int(x) & 0xFF:02X}")
    np.savetxt(filename, hex_format(matrix), fmt="%s", delimiter=" ")
    print(f"Saved {filename} with shape {matrix.shape}")


if __name__ == "__main__":
    images = load_mnist_images("train-images.idx3-ubyte")
    idx = random.randint(0, len(images) - 1)

    # Extract 16x16 crop
    img_16x16 = images[idx][6:22, 6:22]
    save_hex_file("input_feature_map.txt", img_16x16)

    kernel = np.array([[1, 2, 1], [2, 4, 2], [1, 2, 1]])
    save_hex_file("kernel.txt", kernel)

    # Perform convolution & Hardware emulation (int8 casting)
    output = conv.convolution_operation.convolve2d(img_16x16, kernel)
    output_hw = output.astype(np.int32) & 0xFF

    save_hex_file("expected_output.txt", output_hw)

    # Quantization analysis
    abs_error = np.abs(output - output_hw)
    print(f"\n--- Analysis ---\nMax Error: {np.max(abs_error)}\nMean Error: {np.mean(abs_error):.2f}")

    # Visualization
    fig, axes = plt.subplots(1, 3, figsize=(15, 5))
    titles = ['Input (16x16)', 'Kernel (3x3)', 'Output (14x14)']
    data = [img_16x16, kernel, output_hw]

    for i in range(3):
        im = axes[i].imshow(data[i], cmap='gray' if i != 1 else 'viridis')
        axes[i].set_title(titles[i])
        fig.colorbar(im, ax=axes[i], fraction=0.046, pad=0.04)

    plt.tight_layout()
    plt.savefig('visualization.png')
    plt.show()