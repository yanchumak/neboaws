import os
import glob
import sys

def main():
  # Check if the correct number of arguments is provided
  if len(sys.argv) != 4:
    print("Usage: python script.py <folder_path> <file_type> <slicing_index>")
    sys.exit(1)

  # Get arguments from command line
  folder_path = sys.argv[1]
  file_type = sys.argv[2]
  slicing_index = int(sys.argv[3])

  # Change to the specified directory
  try:
    os.chdir(folder_path)
  except FileNotFoundError as e:
    print(f"Directory not found: {e}")
    sys.exit(1)
  
  # Iterate through files with the specified extension
  for file in glob.glob(f"*.{file_type}"):
    file_name, extension = os.path.splitext(file)
    new_file_name = file_name[:-slicing_index] + extension
    try:
      os.rename(file, new_file_name)
    except OSError as e:
      print(f"Error renaming file {file}: {e}")
    else:
      print(f"Renamed {file} to {new_file_name}")

if __name__ == "__main__":
  main()