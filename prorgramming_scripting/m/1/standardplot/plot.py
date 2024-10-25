# plot.py
import matplotlib.pyplot as plt

# Sample data
x = [1, 2, 3, 4, 5]
y = [2, 4, 6, 8, 10]

# Create the plot
plt.plot(x, y, label='Linear Growth')

# Add labels and title
plt.xlabel('X axis')
plt.ylabel('Y axis')
plt.title('Simple Line Plot')

# Show the legend
plt.legend()

# Display the plot
plt.show()
