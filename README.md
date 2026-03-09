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
## Router or URLS
1. Register User
   
   Method: POST
   
   Used to create a new user account.
```bash
    http://127.0.0.1:8000/account/register/
```
2. User Login
   
   Method: POST
   
   Used for user authentication and login.
```bash
    http://127.0.0.1:8000/account/login/
```
3. User Logout
   
   Method: POST
   
   Logs out the currently authenticated user.
```bash
    http://127.0.0.1:8000/account/logout/
```
4. Get Movie List

   Method: GET
  
   Returns a list of all available movies.
```bash
    http://127.0.0.1:8000/movie/list/
```
5. Stream Platform

   Methods: GET, POST

   Admin users: Can perform GET and POST

   Regular users: Can only perform GET
```bash
    http://127.0.0.1:8000/movie/stream/
```
6. Review Detail

   Endpoint for a specific review (example: review id = 3)

   Methods:

         Authenticated users: GET, PUT, DELETE

         Unauthenticated users: GET only
```bash
    http://127.0.0.1:8000/movie/review/3/
```
7. Movie Reviews List

    Get all reviews for a specific movie (example: movie id = 6).

    Method: GET
```bash
    http://127.0.0.1:8000/movie/6/reviews/
```
8. Create Review for a Movie

   Create a review for a specific movie (example: movie id = 6).

   Method: POST
```bash
    http://127.0.0.1:8000/movie/6/create-review/
```
9. Filter Reviews

   Retrieve reviews using filters.

   Method: GET
```bash
    http://127.0.0.1:8000/movie/reviews/
```
