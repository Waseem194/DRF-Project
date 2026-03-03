from rest_framework import serializers
from drf_app.models import Review, WatchList,StreamPlatform

class ReviewSerializer(serializers.ModelSerializer):
  review_user = serializers.StringRelatedField()
  class Meta:
    model = Review
    exclude = ['watchlist']
    # fields = "__all__"
    
class WatchListSerializer(serializers.ModelSerializer):
  # len_name = serializers.SerializerMethodField()
  reviews = ReviewSerializer(many=True,read_only=True)
  class Meta:
    model = WatchList
    fields = "__all__"

class StreamPlatformSerializer(serializers.ModelSerializer):
  watchlist = WatchListSerializer(many=True,read_only = True)
  # watchlist = serializers.StringRelatedField(many=True)
  # watchlist = serializers.PrimaryKeyRelatedField(many=True, read_only=True)
  # watchlist = serializers.HyperlinkedRelatedField(many=True,read_only=True,
  #                                     view_name='stream_detail'                              
  #   )
  class Meta:
    model = StreamPlatform
    fields = "__all__"
    
    # Validation
  # def get_len_name(self,object):
  #   return len(object.name)
    
  # def validate(self,data):
  #   if data['name'] == data['description']:
  #     raise serializers.ValidationError("The name and Description are same!")
  #   else:
  #     return data
    
  # def validate_name(self,value):
  #   if len(value) < 2:
  #     raise serializers.ValidationError("The Name is too Short!")
  #   else:
  #     return value
    
    
# class MovieSerializer(serializers.Serializer):
#   id = serializers.IntegerField(read_only=True)
#   name = serializers.CharField()
#   description = serializers.CharField()
#   active = serializers.BooleanField()
  
#   def create(self,validated_data):
#     return Movie.objects.create(**validated_data)
  
#   def update(self,instance,validate_data):
#     instance.name = validate_data.get('name',instance.name)
#     instance.description = validate_data.get('description',instance.description)
#     instance.active = validate_data.get('active',instance.active)
#     instance.save()
#     return instance
  
  # def validate(self,data):
  #   if data['name'] == data['description']:
  #     raise serializers.ValidationError("The name and Description are same!")
  #   else:
  #     return data
    
  # def validate_name(self,value):
  #   if len(value) < 2:
  #     raise serializers.ValidationError("The Name is too Short!")
  #   else:
  #     return value
    