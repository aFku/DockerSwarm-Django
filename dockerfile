FROM python:3
EXPOSE 8080

ADD /Django-MultiApp/ /
ADD wait-for-it.sh /
RUN pip install -r requirements.txt
WORKDIR /
CMD ["python3", "manage.py", "makemigrations", "QuestionSite"]
CMD ["python3", "manage.py", "migrate", "QuestionSite"]
