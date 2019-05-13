FROM mcr.microsoft.com/dotnet/core/aspnet:2.2-stretch-slim AS base
RUN useradd --create-home -s /bin/bash user
WORKDIR /home/user
USER user
ENV APP_HOME /home/user/app
RUN mkdir $APP_HOME
EXPOSE 5001

FROM mcr.microsoft.com/dotnet/core/sdk:2.2-stretch AS build
WORKDIR /src
COPY ["WebStress.csproj", "."]
RUN dotnet restore "WebStress.csproj"
COPY . .
WORKDIR "/src"
RUN dotnet build "WebStress.csproj" -c Release -o /app

FROM build AS publish
RUN dotnet publish "WebStress.csproj" -c Release -o /app

FROM base AS final
USER user
WORKDIR $APP_HOME
COPY --from=publish /app .
ENTRYPOINT ["dotnet", "WebStress.dll"]
