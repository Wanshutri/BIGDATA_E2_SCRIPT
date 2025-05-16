FROM python:3.9-slim
# Establece el directorio de trabajo
WORKDIR /app


# Copia los archivos locales al contenedor
COPY . /app


# Instala las dependencias
RUN pip install --no-cache-dir -r requirements.txt


# Expone el puerto 8000 para la app
EXPOSE 8000


# Define el comando para ejecutar la aplicación
CMD ["python", "main.py"]