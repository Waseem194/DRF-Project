# DRF-Project

## 🚀 How to Run This Project

1. Make sure you have atleast `Python 3.14.3` installed.
2. Create virtual envirement Through this command:

```bash
python -m venv <environment_name>
```

3. Activate your newly created virtual environment by this command

```bash
source <env_name>/bin/activate  -- MACOS
source <env_name>/Scripts/activate -- Windows
```

4. After creating virtual envirement Then install requirements.txt through this command:

```bash
pip install -r requirements.txt
```

5. After this to Navigate manage.py file then run this command:

```bash
python manage.py runserver
```


6. Run docker commands

#### Build and start docker container

```bash
docker compose up -d
```

#### Kill and stop running docker container

```bash
docker compose down
```