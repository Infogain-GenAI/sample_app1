import os

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy import Column, Integer, String, create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

APP_NAME = os.getenv("APP_NAME", "sample-app")
DB_PATH = os.getenv("DB_PATH", "data/app.db")
SECRET_KEY = os.getenv("SECRET_KEY", "dev-secret")
PORT = int(os.getenv("PORT", "8000"))

os.makedirs(os.path.dirname(DB_PATH) or ".", exist_ok=True)

engine = create_engine( 
    f"sqlite:///{DB_PATH}", connect_args={"check_same_thread": False}
) 
SessionLocal = sessionmaker(bind=engine)
Base = declarative_base()


class Todo(Base): 
    __tablename__ = "todos"
    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)


Base.metadata.create_all(bind=engine)
app = FastAPI(title=APP_NAME)

app.add_middleware(
    CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"]
)


@app.get("/api/todos")
def list_todos(): 
    db = SessionLocal()
    return [{"id": t.id, "title": t.title} for t in db.query(Todo).all()]


@app.post("/api/todos")
def create_todo(title: str):
    if not title:
        raise HTTPException(status_code=400, detail="title required")
    db = SessionLocal()
    todo = Todo(title=title)
    db.add(todo)
    db.commit()
    db.refresh(todo)
    return {"id": todo.id, "title": todo.title}


# Mount static files LAST so API routes take precedence
app.mount("/", StaticFiles(directory="frontend", html=True), name="static")
