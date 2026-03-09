from django.shortcuts import get_object_or_404
from rest_framework.exceptions import ValidationError
from rest_framework.response import Response
from rest_framework import status,generics,mixins,viewsets
# from rest_framework.decorators import api_view
from rest_framework.permissions import IsAuthenticated
from drf_app.api.permissions import IsAdminOrReadOnly,IsReviewUserOrReadOnly
from rest_framework.throttling import UserRateThrottle,AnonRateThrottle,ScopedRateThrottle
from rest_framework.views import APIView
from drf_app.models import Review, StreamPlatform, WatchList
from drf_app.api.serializers import (ReviewSerializer, StreamPlatformSerializer, 
                                     WatchListSerializer)
from drf_app.api.throttling import ReviewCreateThrottle, ReviewListThrottle 
# Concrete View Classes


class UserReview(generics.ListAPIView):
  serializer_class = ReviewSerializer
  # def get_queryset(self):
  #   username = self.kwargs['username']
  #   return Review.objects.filter(review_user__username=username)
  def get_queryset(self):
    username = self.request.query_params.get('username')
    return Review.objects.filter(review_user__username=username)
  
  
class ReviewCreate(generics.CreateAPIView):
  serializer_class = ReviewSerializer
  permission_classes = [IsAuthenticated]
  throttle_classes = [ReviewCreateThrottle]
  def get_queryset(self):
      return Review.objects.all()
  
  def perform_create(self, serializer):
    pk = self.kwargs.get('pk')
    movie = get_object_or_404(WatchList,pk=pk)
    review_user = self.request.user
    review_queryset = Review.objects.filter(watchlist=movie,review_user=review_user)
    if review_queryset.exists():
      raise ValidationError("You have already Reviewed this Movie!")
    if movie.number_rating == 0:
      movie.avg_rating = serializer.validated_data['rating'] 
    else: 
      movie.avg_rating = (movie.avg_rating + serializer.validated_data['rating'])/2
    movie.number_rating += 1
    movie.save()
    serializer.save(watchlist=movie,review_user=review_user)


class ReviewList(generics.ListAPIView):
  # queryset = Review.objects.all()
  serializer_class = ReviewSerializer
  throttle_classes = [ReviewCreateThrottle]
  # permission_classes = [ReviewUserOrReadOnly]
  # permission_classes = [IsAuthenticated]
  def get_queryset(self):
    pk = self.kwargs['pk']
    return Review.objects.filter(watchlist=pk)

class ReviewDetail(generics.RetrieveUpdateDestroyAPIView):
  queryset = Review.objects.all()
  serializer_class = ReviewSerializer
  permission_classes = [IsReviewUserOrReadOnly]
  throttle_classes = [ScopedRateThrottle]
  throttle_scope = 'review-detail'
  # permission_classes = [IsAuthenticated]
  
# Uing Mixins
# class ReviewDetail(mixins.RetrieveModelMixin,generics.GenericAPIView):
#   queryset = Review.objects.all()
#   serializer_class = ReviewSerializer
#   def get(self, request, *args, **kwargs):
#         return self.retrieve(request, *args, **kwargs)
      
# class ReviewList(
#       mixins.ListModelMixin, mixins.CreateModelMixin, generics.GenericAPIView):
#     queryset = Review.objects.all()
#     serializer_class = ReviewSerializer
#     def get(self, request, *args, **kwargs):
#         return self.list(request, *args, **kwargs)
#     def post(self, request, *args, **kwargs):
#         return self.create(request, *args, **kwargs)

# ViewSets & Routers

class StreamPlatformVS(viewsets.ModelViewSet):
    permission_classes = [IsAdminOrReadOnly]
    queryset = StreamPlatform.objects.all()
    serializer_class = StreamPlatformSerializer
    # permission_classes = [IsAuthenticated]
# class StreamPlatformVS(viewsets.ViewSet):
#     """
#     A simple ViewSet for listing or retrieving users.
#     """
#     def list(self, request):
#         queryset = StreamPlatform.objects.all()
#         serializer = StreamPlatformSerializer(queryset, many=True)
#         return Response(serializer.data)

#     def retrieve(self, request, pk=None):
#         queryset = StreamPlatform.objects.all()
#         watchlist = get_object_or_404(queryset, pk=pk)
#         serializer = StreamPlatformSerializer(watchlist)
#         return Response(serializer.data)
      
#     def create(self,request):
#       serializer = StreamPlatformSerializer(data=request.data)
#       if serializer.is_valid():
#         serializer.save()
#         return Response(serializer.data)
#       else:
#           return Response(serializer.errors)
#     def destroy(self, request, pk=None):
#       delete_watch_list = get_object_or_404(StreamPlatform,pk=pk)
#       delete_watch_list.delete()
#       return Response({'detail':'WatchList Has Been Deleted'},
#                     status=status.HTTP_204_NO_CONTENT)
      
          
      
# Class-Based Views
# class StreamPlatformAV(APIView):
#   permission_classes = [IsAdminOrReadOnly]
#   def get(self,request,pk=None):
#     platform = StreamPlatform.objects.all()
#     serializer = StreamPlatformSerializer(platform,many= True)
#     return Response(serializer.data)
  
#   def post(self,request):
#     serializer = StreamPlatformSerializer(data=request.data)
#     if serializer.is_valid():
#       serializer.save()
#       return Response(serializer.data)
#     else:
#       return Response(serializer.error)
    

# class StreamPlatformDetailAV(APIView):
#   permission_classes = [IsAdminOrReadOnly]
#   def get(self,request,pk):
#     try:
#       stream = get_object_or_404(StreamPlatform,pk=pk)
#     except WatchList.DoesNotExist:
#       return Response({'error':'Movie Not found'},
#                       status=status.HTTP_404_NOT_FOUND
#                       )
#     serializer = StreamPlatformSerializer(stream)
#     return Response(serializer.data)
  
#   def put(self,request,pk):
#     update_stream = get_object_or_404(StreamPlatform,pk=pk)
#     serializer = StreamPlatformSerializer(update_stream,data=request.data)
#     if serializer.is_valid():
#       serializer.save()
#       return Response(serializer.data)
#     else:
#       return Response(serializer.errors,
#                       status=status.HTTP_400_BAD_REQUEST)
#   def delete(self,request,pk):
#     delete_movie = get_object_or_404(StreamPlatform,pk=pk)
#     delete_movie.delete()
#     return Response({'detail':'Movie Has Been Deleted'},
#                     status=status.HTTP_204_NO_CONTENT)
    
    
class WatchListAV(APIView):
  permission_classes = [IsAdminOrReadOnly]
  def get(self,request):
    movies = WatchList.objects.all()
    serializer = WatchListSerializer(movies,many=True)
    return Response(serializer.data)
  
  def post(self,request):
    serializer = WatchListSerializer(data=request.data)
    if serializer.is_valid():
      serializer.save()
      return Response(serializer.data)
    else:
      return Response(serializer.errors)

class WatchDetailAV(APIView):
  permission_classes = [IsAdminOrReadOnly]
  def get(self,request,pk):
    try:
      movie = get_object_or_404(WatchList,pk=pk)
    except WatchList.DoesNotExist:
      return Response({'error':'Movie Not found'},
                      status=status.HTTP_404_NOT_FOUND
                      )
    serializer = WatchListSerializer(movie)
    return Response(serializer.data)
  
  def put(self,request,pk):
    update_movies = get_object_or_404(WatchList,pk=pk)
    serializer = WatchListSerializer(update_movies,data=request.data)
    if serializer.is_valid():
      serializer.save()
      return Response(serializer.data)
    else:
      return Response(serializer.errors,
                      status=status.HTTP_400_BAD_REQUEST)
  def delete(self,request,pk):
    delete_movie = get_object_or_404(WatchList,pk=pk)
    delete_movie.delete()
    return Response({'detail':'Movie Has Been Deleted'},
                    status=status.HTTP_204_NO_CONTENT)
    
    
# Function Based Views
# @api_view(['GET','POST'])
# def movie_list(request):
#   if request.method == 'GET':
#     movies = Movie.objects.all()
#     serializer = MovieSerializer(movies,many=True)
#     return Response(serializer.data)
#   if request.method == 'POST':
#     serializer = MovieSerializer(data=request.data)
#     if serializer.is_valid():
#       serializer.save()
#       return Response(serializer.data)
#     else:
#       return Response(serializer.errors)
    

# @api_view(['GET','PUT','DELETE'])
# def movie_detail(request,pk):
#   if request.method == 'GET':
#     try:
#       movie = Movie.objects.get(pk=pk)
#     except Movie.DoesNotExist:
#       return Response({'Error':'Movie Not Found'},
#                       status=status.HTTP_404_NOT_FOUND)
#     serializer = MovieSerializer(movie)
#     return Response(serializer.data)
  
#   if request.method == 'PUT':
#     update_movie = Movie.objects.get(pk=pk)
#     serializer = MovieSerializer(update_movie,data=request.data)
#     if serializer.is_valid():
#       serializer.save()
#       return Response(serializer.data)
#     else:
#       return Response(serializer.errors,status=status.HTTP_400_BAD_REQUEST)
  
#   if request.method == 'DELETE':
#     delete_items = Movie.objects.get(pk=pk)
#     delete_items.delete()
#     return Response({"detail":"This item is deleted"},status=status.HTTP_204_NO_CONTENT)
    

