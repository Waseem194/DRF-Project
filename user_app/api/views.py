from rest_framework.decorators import api_view
from user_app.api.serializers import RegistrationSerializer
from rest_framework.response import Response
from rest_framework.authtoken.models import Token
from rest_framework import status,generics,mixins,viewsets
# from user_app import models
# @api_view(['POST',])
# def registration_view(request):
#   if request.method == 'POST':
#     serializer = RegistrationSerializer(data=request.data)
#     data = {}
#     if serializer.is_valid():
#       account = serializer.save()
#       data['response'] = "Registration Successfull!"
#       data['username'] = account.username
#       data['eamil'] = account.email
#       token = Token.objects.get(user=account).key
#       data['token'] = token
#     else:
#       data = serializer.errors
#       return Response(data)



@api_view(['POST'])
def logout_view(request):
    if request.method == 'POST':
        request.user.auth_token.delete()
        return Response({"message": "Logged out successfully"}, status=status.HTTP_200_OK)
    else:
        return Response({"error": "User not authenticated"}, status=status.HTTP_401_UNAUTHORIZED)

from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.exceptions import AuthenticationFailed

@api_view(['POST'])
def registration_view(request):
    serializer = RegistrationSerializer(data=request.data)

    if serializer.is_valid():
        user = serializer.save()
        # token, created = Token.objects.get_or_create(user=user)
        refresh = RefreshToken.for_user(user)

        return Response({
            "message": "Registration Successful!",
            "username": user.username,
            "email": user.email,
            # "token": token.key
            'refresh': str(refresh),
            'access': str(refresh.access_token),
        }, status=status.HTTP_201_CREATED)
     
    return Response({
        "message": "Registration Failed!",
        "errors":serializer.errors}, status=status.HTTP_400_BAD_REQUEST)