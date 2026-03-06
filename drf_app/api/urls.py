from django.urls import include, path
from rest_framework.routers import DefaultRouter
# from drf_app.api.views import movie_list,movie_detail
from drf_app.api.views import (ReviewCreate,ReviewDetail,ReviewList,WatchListAV,
                               WatchDetailAV,StreamPlatformVS)

router = DefaultRouter()

router.register('stream',StreamPlatformVS,basename='StreamPlatform')

urlpatterns= [
  path('list/',WatchListAV.as_view(),name='movie_list'),
  path('<int:pk>/',WatchDetailAV.as_view(),name='movie_detail'),
  
  path("",include(router.urls)),
  
  # path('stream/',StreamPlatformAV.as_view(),name='stream'),
  # path('stream/<int:pk>/',StreamPlatformDetailAV.as_view(),name='stream_detail'),
  
  # path('review/',ReviewList.as_view(),name='review_list'),
  # path('review/<int:pk>/',ReviewDetail.as_view(),name='review_detail')
  
  path('<int:pk>/create-review/',ReviewCreate.as_view(),name='review_create'),
  path('<int:pk>/reviews/',ReviewList.as_view(),name='review_list'),
  path('review/<int:pk>/',ReviewDetail.as_view(),name='review_detail')
]