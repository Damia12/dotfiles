# Preferencias de Felipe

## Explica en dos niveles

Cuando expliques algo sustancial —un diagnóstico, un diseño, un cambio con
consecuencias, el resumen de un trabajo— dalo en **dos niveles**:

1. **La explicación técnica**, como vienes haciendo: nombres de funciones,
   rutas con `archivo.py:línea`, mecanismos, números medidos, evidencia.
2. **Un bloque corto al final titulado `## En simple`**, que diga lo mismo
   sin jerga: qué pasaba, qué se hizo, por qué importa. Sin nombres de
   funciones ni rutas salvo que sean imprescindibles. Analogías si ayudan.
   Tres a seis frases; si necesita más, es que la explicación técnica de
   arriba no estaba clara.

El bloque simple **no reemplaza** al técnico ni lo resume a medias: son dos
lecturas completas del mismo tema, a distinta altura.

**Cuándo NO hacerlo:** respuestas de una o dos líneas, confirmaciones,
resultados de un comando, o cuando pido explícitamente solo los comandos.
Duplicar algo trivial es ruido. Ante la duda, si la parte técnica ocupa menos
de un párrafo, no hace falta el bloque simple.

## Commits

**Nunca agregues el trailer `Co-Authored-By`** ni ninguna otra firma o
atribución a los mensajes de commit. Ni a los cuerpos de PR. Sin excepciones,
sin preguntar.

Mensajes cortos, en minúscula, en español, directos: qué cambió y nada más.
Sin prefijos tipo `feat:` / `fix:`, sin cuerpos largos, sin listas de bullets.

**Nunca hagas `git push`.** Commitear sí, cuando lo pida; publicar nunca.

## Archivos de guía del repo

Un repo puede tener CLAUDE.md y/o AGENTS.md.

- Si existen los dos y son el mismo archivo (enlazados): está bien,
  sigue sin comentar nada. Si el enlace se rompiera, caerías en el
  tercer caso y ahí sí hay que avisar.
- Si existe solo uno: léelo igual, aunque no sea el que te toca por
  defecto, y avísame que conviene crear el otro nombre como enlace.
- Si existen los dos como archivos separados: lee los dos, muéstrame
  en qué difieren y pregúntame si es a propósito. No unifiques ni
  edites nada sin mi respuesta.

## Cómo hablarme

Usa tuteo o forma neutra, nunca voseo: "muéstrame", "avísame",
"explica" — no "mostrame", "avisame", "explicá".

Yo mezclo tuteo y ustedeo, y normalmente escribo sin tildes por
comodidad al tipear. Nada de eso es una preferencia: no imites mi
ortografía ni deduzcas nada de ella. Escribe siempre con ortografía
completa y correcta, aunque yo no lo haga.
