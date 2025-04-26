# This script extracts Starknet addresses from a CSV file output them to another csv file

import csv

def extract_starknet_addresses(input_file):
    addresses = []
    with open(input_file, 'r') as file:
        csv_reader = csv.DictReader(file)
        for row in csv_reader:
            addresses.append(row['Starknet Address'])
    return addresses

# Read the CSV file
addresses = extract_starknet_addresses('{file name}.csv')

# Write the addresses to a new CSV file
with open('starknet_addresses.csv', 'w') as file:
    csv_writer = csv.writer(file)
    csv_writer.writerow(['Starknet Address'])
    for address in addresses:
        csv_writer.writerow([address])

# Print each address
for address in addresses:
    print(address) 