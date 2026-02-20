conda activate crawler
python data_scripts/crawler.py
python data_scripts/generate_indoor_facts.py
python data_scripts/combine_facts.py
clips -f run.clp
