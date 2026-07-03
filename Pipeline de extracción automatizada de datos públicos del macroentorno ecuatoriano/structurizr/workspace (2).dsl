workspace "Pipeline RPA - Macroentorno" "Modelo C4 del pipeline de extracción, validación y almacenamiento de datos macroeconómicos (4to ciclo)" {

    !identifiers hierarchical

    model {

        equipoDatos = person "Equipo de Datos" "Recoge y procesa los archivos publicados en datos_macroentorno/" "Persona"

        bce       = softwareSystem "BCE" "Banco Central del Ecuador.\nCuentas Nacionales, Sector Real (IEE), Sector Externo (precio petróleo), Publicaciones (riesgo país)." "Fuente Externa"
        inec      = softwareSystem "INEC" "Instituto Nacional de Estadística y Censos.\nENEMDU (trimestral) y Censo 2022 (estático)." "Fuente Externa"
        supercias = softwareSystem "SUPERCIAS" "Superintendencia de Compañías.\nRanking de empresas (anual) y Directorio de compañías (mensual, formulario JSF)." "Fuente Externa"
        mineduc   = softwareSystem "MINEDUC" "Ministerio de Educación.\nAMIE, registro administrativo anual." "Fuente Externa"
        msgSystem = softwareSystem "Email / Slack" "Canal de mensajería usado para alertas de error y notificaciones de archivos nuevos." "Sistema Externo"

        pipeline = softwareSystem "Pipeline RPA Macroentorno" "Automatiza la extracción, validación, almacenamiento y notificación de datos macroeconómicos publicados por fuentes gubernamentales ecuatorianas." {

            n8n = container "N8N" "Orquesta la extracción automatizada de las 8 fuentes con descarga directa (HTTP Request / scraping simple)." "n8n (workflow automation)" "Automatizacion" {
                trigger        = component "Schedule Trigger" "Dispara la ejecución según la periodicidad de cada fuente: diario, semanal, mensual, trimestral o anual." "n8n Trigger Node"
                extraccion     = component "Módulo de Extracción" "Realiza HTTP Request o navegación web simple para descargar el archivo de la fuente." "n8n Function/HTTP Node"
                guardarArchivo = component "Módulo de Guardado" "Guarda el archivo descargado aplicando la nomenclatura nombre_AAAAMMDD.ext (ej. pib_real_20260512.xlsx)." "n8n Function Node"
                validacion     = component "Módulo de Validación" "Verifica que el archivo no esté vacío y que el formato/extensión sea el esperado." "n8n IF Node"
                manejoErrores  = component "Manejador de Errores" "Registra el error (fuente, fecha, detalle), dispara la alerta interna y permite que el pipeline continúe con la siguiente fuente sin reintentar." "n8n Function Node"
            }

            uipath = container "Robot UiPath" "Robot RPA que completa el formulario JSF y descarga el Directorio de Compañías de SUPERCIAS." "UiPath Studio / Robot" "RPA" {
                completarFormulario = component "Completar Formulario JSF" "Navega el portal de SUPERCIAS y completa el formulario JSF requerido para acceder al Directorio de compañías." "UiPath Activity"
                descargarArchivo    = component "Descargar Archivo" "Descarga el archivo del Directorio una vez enviado el formulario." "UiPath Activity"
            }

            almacenamiento = container "Almacenamiento de Archivos" "Estructura de carpetas datos_macroentorno/ organizada por fuente y categoría (bce/, inec/, supercias/, mineduc/), con nomenclatura nombre_AAAAMMDD.ext para trazabilidad y reproducibilidad." "Sistema de archivos" "Almacenamiento"

            registroErrores = container "Registro de Errores" "Guarda el log de errores por fuente: fecha, detalle del fallo, sin reintento automático." "Archivo de log" "Almacenamiento"

            notificador = container "Servicio de Notificaciones" "Envía alertas internas de error y avisa cuando hay archivos nuevos disponibles en datos_macroentorno/." "Script de integración" "Notificacion"
        }

        // Relaciones fuentes -> herramientas de extracción
        bce -> pipeline.n8n "Provee datos (Cuentas Nacionales, Sector Real, Sector Externo, Publicaciones)" "HTTPS"
        inec -> pipeline.n8n "Provee datos (ENEMDU, Censo 2022)" "HTTPS"
        mineduc -> pipeline.n8n "Provee datos (AMIE)" "HTTPS"
        supercias -> pipeline.n8n "Provee datos (Ranking de empresas)" "HTTPS"
        supercias -> pipeline.uipath "Provee datos (Directorio de compañías vía formulario JSF)" "HTTPS"

        // Relaciones a nivel de contenedor
        pipeline.n8n -> pipeline.almacenamiento "Guarda archivo validado en"
        pipeline.uipath -> pipeline.almacenamiento "Guarda archivo validado en"
        pipeline.n8n -> pipeline.registroErrores "Registra errores en"
        pipeline.uipath -> pipeline.registroErrores "Registra errores en"
        pipeline.n8n -> pipeline.notificador "Dispara alerta interna de error"
        pipeline.uipath -> pipeline.notificador "Dispara alerta interna de error"
        pipeline.almacenamiento -> pipeline.notificador "Dispara notificación de archivos nuevos"
        pipeline.notificador -> msgSystem "Envía mensaje" "Email / Slack API"
        msgSystem -> equipoDatos "Notifica archivos nuevos / errores"
        equipoDatos -> pipeline.almacenamiento "Recoge y procesa archivos desde"

        // Relaciones a nivel de componente (dentro de N8N)
        pipeline.n8n.trigger -> pipeline.n8n.extraccion "Inicia"
        pipeline.n8n.extraccion -> pipeline.n8n.guardarArchivo "Entrega archivo descargado a"
        pipeline.n8n.guardarArchivo -> pipeline.n8n.validacion "Envía a validar"
        pipeline.n8n.validacion -> pipeline.almacenamiento "Sí: archivo válido, se guarda en"
        pipeline.n8n.validacion -> pipeline.n8n.manejoErrores "No: archivo inválido"
        pipeline.n8n.manejoErrores -> pipeline.registroErrores "Registra error en"
        pipeline.n8n.manejoErrores -> pipeline.notificador "Alerta interna"
        pipeline.n8n.manejoErrores -> pipeline.n8n.trigger "Continúa con la siguiente fuente (sin reintentar)"

        // Relaciones a nivel de componente (dentro de UiPath)
        supercias -> pipeline.uipath.completarFormulario "Formulario JSF de Directorio"
        pipeline.uipath.completarFormulario -> pipeline.uipath.descargarArchivo "Envía formulario y habilita descarga"
        pipeline.uipath.descargarArchivo -> pipeline.almacenamiento "Guarda archivo válido en"
        pipeline.uipath.descargarArchivo -> pipeline.registroErrores "Registra error si falla"
    }

    views {

        systemContext pipeline "SystemContext" {
            include *
            autolayout lr
            title "Diagrama de Contexto del Sistema - Pipeline RPA Macroentorno"
            description "Vista de alto nivel: fuentes gubernamentales, el pipeline RPA, el canal de notificaciones y el equipo de datos."
        }

        container pipeline "Containers" {
            include *
            autolayout lr
            title "Diagrama de Contenedores - Pipeline RPA Macroentorno"
            description "N8N y UiPath extraen datos de las fuentes, los almacenan en datos_macroentorno/, registran errores y notifican al equipo de datos."
        }

        component pipeline.n8n "N8N_Components" {
            include *
            autolayout lr
            title "Diagrama de Componentes - N8N"
            description "Patrón de flujo repetido por cada fuente: trigger, extracción, guardado, validación y manejo de errores."
        }

        component pipeline.uipath "UiPath_Components" {
            include *
            autolayout lr
            title "Diagrama de Componentes - Robot UiPath"
            description "El robot completa el formulario JSF de SUPERCIAS y descarga el Directorio de compañías."
        }

        styles {
            element "Persona" {
                shape person
                background #3B6D11
                color #ffffff
            }
            element "Fuente Externa" {
                background #0F6E56
                color #ffffff
            }
            element "Sistema Externo" {
                background #6c757d
                color #ffffff
            }
            element "Software System" {
                background #1168bd
                color #ffffff
            }
            element "Automatizacion" {
                background #534AB7
                color #ffffff
            }
            element "RPA" {
                background #993C1D
                color #ffffff
            }
            element "Almacenamiento" {
                background #5F5E5A
                color #ffffff
            }
            element "Notificacion" {
                background #3B6D11
                color #ffffff
            }
            element "Component" {
                background #85BBF0
                color #000000
            }
        }
    }

}
