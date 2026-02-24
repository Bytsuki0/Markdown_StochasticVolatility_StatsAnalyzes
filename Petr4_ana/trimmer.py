import pandas as pd
import os

# ==============================
# STEP 1: Define file path
# ==============================

input_file = r"Petr4_ana\IBM_data.csv"

# ==============================
# STEP 2: Load dataset
# ==============================

df = pd.read_csv(input_file)

# ==============================
# STEP 3: Compute split size
# ==============================

total_rows = len(df)
chunk_size = total_rows // 3  # integer division

# ==============================
# STEP 4: Split into 3 parts
# ==============================

df1 = df.iloc[:chunk_size]
df2 = df.iloc[chunk_size:2*chunk_size]
df3 = df.iloc[2*chunk_size:]

# ==============================
# STEP 5: Save files
# ==============================

base_dir = os.path.dirname(input_file)

df1.to_csv(os.path.join(base_dir, "IBM_data_part1.csv"), index=False)
df2.to_csv(os.path.join(base_dir, "IBM_data_part2.csv"), index=False)
df3.to_csv(os.path.join(base_dir, "IBM_data_part3.csv"), index=False)

print("File successfully split into 3 parts.")