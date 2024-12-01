sudo yum install python3-pip
ppython3 -m pip install boto3 redis argparse

python3 app.py --host master.rg1.vynugr.use1.cache.amazonaws.com --cluster rg1 --user user