# from django.shortcuts import get_object_or_404, render
# from drf_app.models import Movie
# from django.http import JsonResponse

# def movie_list(request):
#   movies = Movie.objects.all()
#   data = {
#     'movies': list(movies.values())
#     }
#   return JsonResponse(data)

# def movie_detail(request,pk):
#   get_single_movie = get_object_or_404(Movie,pk=pk)  
  
#   # single_movie = Movie.obj4ects.get(pk=pk)
  
#   print(get_single_movie)
  
