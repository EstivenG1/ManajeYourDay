drop trigger if exists al_crear_usuario on auth.users;

create trigger al_crear_usuario
  after insert on auth.users
  for each row execute function public.manejar_nuevo_usuario();
