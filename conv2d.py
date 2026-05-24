import numpy as np


class convolution_operation:
    @staticmethod
    def convolve2d(input_data, kernel):
        # Get dimensions
        in_h, in_w = input_data.shape
        k_h, k_w = kernel.shape

        # Calculate output size
        out_h, out_w = in_h - k_h + 1, in_w - k_w + 1
        output = np.zeros((out_h, out_w))

        # Sliding window convolution
        for i in range(out_h):
            for j in range(out_w):
                region = input_data[i:i + k_h, j:j + k_w]
                # MAC operation (no bit-shifting as per hardware spec)
                output[i, j] = np.sum(region * kernel)

        return output


# Simple testbench
if __name__ == "__main__":
    input_data = np.array([[1, 2, 3], [0, 1, 4], [1, 0, 2]])
    kernel = np.array([[0, 1], [2, 1]])

    output = convolution_operation.convolve2d(input_data, kernel)

    print("Input:\n", input_data)
    print("Kernel:\n", kernel)
    print("Output:\n", output)