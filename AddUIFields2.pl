#!perl
#
# AddUiFields.pl
#
# This utility is for adding new uifields to Trivox
# 
use warnings;
use strict;
use feature 'state';
use utf8;
use Encode::Encoder qw(encoder);
use Encode qw(is_utf8 encode_utf8 decode_utf8 _utf8_off);
use LWP::UserAgent;
use JSON;
use URI::Escape qw(uri_escape uri_escape_utf8);
use Gnu::TinyDB;
use Gnu::ArgParse;
use Gnu::StringUtil qw(HtmlEncode Trim);
use Gnu::DebugUtil  qw(DumpHash DumpRef);


my @FIELDS = (
   {e=>"Demonstration Module"                                                          ,  s=>"M�dulo de demostraci�n"                                                   },
   {e=>"End of set"                                                                    ,  s=>"Fin del juego"                                                            },
   {e=>"Nutrition - Parent"                                                            ,  s=>"Nutrici�n - Padres"                                                       },
   {e=>"Nutrition - Child"                                                             ,  s=>"Nutrici�n - Ni�o"                                                         },
   {e=>"Core Screener"                                                                 ,  s=>"Core Screener"                                                            },
   {e=>"DMC Intake - Red Flags"                                                        ,  s=>"DMC ingesta - Banderas Rojas"                                             },
   {e=>"End of core"                                                                   ,  s=>"Fin del n�cleo"                                                           },
   {e=>"Gateway"                                                                       ,  s=>"Puerta"                                                                   },
   {e=>"End of gateway questions"                                                      ,  s=>"Fin de preguntas de puerta de enlace"                                     },
   {e=>"Core Demonstration"                                                            ,  s=>"Demostraci�n Core"                                                        },
   {e=>"Vanderbilt - Parent"                                                           ,  s=>"Vanderbilt - Padres"                                                      },
   {e=>"Physical Activity, ages 2-11"                                                  ,  s=>"La actividad f�sica, las edades de 2-11"                                  },
   {e=>"ASK - Parent Intake"                                                           ,  s=>"ASK - Ingesta de Padres"                                                  },
   {e=>"Family Empowerment Scale"                                                      ,  s=>"Empoderamiento de la escala de la familia"                                },
   {e=>"Vanderbilt - Just first 18 questions"                                          ,  s=>"Vanderbilt - A s�lo 18 primeras preguntas"                                },
   {e=>"Parent Report of School Liking and Avoidance "                                 ,  s=>"Padre Informe del Gusto Escuela y Prevenci�n"                             },
   {e=>"Student Engagement vs. Disaffection in School"                                 ,  s=>"Student Engagement vs El descontento en la Escuela"                       },
   {e=>"Self Report of School Liking  and Avoidance"                                   ,  s=>"Informe de Auto Escuela Gusto y Prevenci�n"                               },
   {e=>"Direct Search Questions"                                                       ,  s=>"B�squeda directa Preguntas"                                               },
   {e=>"Vanderbilt - Parent - Performance"                                             ,  s=>"Vanderbilt - Padres - Rendimiento"                                        },
   {e=>"Core Screener Follow-Up"                                                       ,  s=>"Core Screener Seguimiento"                                                },
   {e=>"Teacher Vanderbilt"                                                            ,  s=>"Maestro de Vanderbilt"                                                    },
   {e=>"Core Screener Follow-Up - Satisfaction"                                        ,  s=>"Core Screener Seguimiento - Satisfacci�n"                                 },
   {e=>"Nutrition Follow-up - Phone intro"                                             ,  s=>"La nutrici�n de Seguimiento - introducci�n del tel�fono"                  },
   {e=>"Nutrition Follow-up - Email intro (1 month)"                                   ,  s=>"La nutrici�n de Seguimiento - Correo electr�nico de introducci�n (1 mes)" },
   {e=>"Nutrition Follow-up - Ending"                                                  ,  s=>"Nutrici�n Seguimiento - Ending"                                           },
   {e=>"Teacher - Student Engagement vs. Disaffection"                                 ,  s=>"Maestro - participaci�n de los estudiantes frente a la desafecci�n"       },
   {e=>"Teacher - SLAQ"                                                                ,  s=>"Maestro - SLAQ"                                                           },
   {e=>"ASK - Parent Follow-up"                                                        ,  s=>"ASK - Padres Seguimiento"                                                 },
   {e=>"NICU-Quality of life Part 1"                                                   ,  s=>"UCIN-Calidad de vida Parte 1"                                             },
   {e=>"Prior Authorization: Introduction"                                             ,  s=>"Autorizaci�n previa: Introducci�n"                                        },
   {e=>"NICU- Pre_Survey"                                                              ,  s=>"Nicu- Pre_Survey"                                                         },
   {e=>"NICU_BehavioralQuestions_Age-0-3"                                              ,  s=>"NICU_BehavioralQuestions_Age-0-3"                                         },
   {e=>"NICU_BehavioralQuestions_Age-4-6"                                              ,  s=>"NICU_BehavioralQuestions_Age-4-6"                                         },
   {e=>"NICU_BehavioralQuestions_Age-7-9"                                              ,  s=>"NICU_BehavioralQuestions_Age-7-9"                                         },
   {e=>"NICU_BehavioralQuestions_Age-10-12"                                            ,  s=>"NICU_BehavioralQuestions_Age-10-12"                                       },
   {e=>"NICU_BehavioralQuestions_Age-13-15"                                            ,  s=>"NICU_BehavioralQuestions_Age-13-15"                                       },
   {e=>"NICU_BehavioralQuestions_Age-16-18"                                            ,  s=>"NICU_BehavioralQuestions_Age-16-18"                                       },
   {e=>"NICU -Quality of life Part 2"                                                  ,  s=>"UCIN -Calidad de vida Parte 2"                                            },
   {e=>"NICU_BehavioralQuestions_Age-19-21"                                            ,  s=>"NICU_BehavioralQuestions_Age-19-21"                                       },
   {e=>"NICU_BehavioralQuestions_Age-above 22"                                         ,  s=>"NICU_BehavioralQuestions_Age anteriormente 22"                            },
   {e=>"DMC Intake - Childs Living Situation"                                          ,  s=>"DMC ingesta - del ni�o Situaci�n de Vivienda"                             },
   {e=>"DMC Intake -  Insurance"                                                       ,  s=>"DMC ingesta - Seguros"                                                    },
   {e=>"Nutrition Study Consent Form"                                                  ,  s=>"Estudio de Consentimiento Nutrici�n"                                      },
   {e=>"Nutrition Follow-up - Email intro (3 month)"                                   ,  s=>"La nutrici�n de Seguimiento - Correo electr�nico de introducci�n (3 mes)" },
   {e=>"Medication Symptoms"                                                           ,  s=>"Los s�ntomas de la medicaci�n"                                            },
   {e=>"PEDSQL - Family Impact Module"                                                 ,  s=>"PedsQL - M�dulo de Impacto de la familia"                                 },
   {e=>"Parent - Patient Overall functioning"                                          ,  s=>"Padre - Paciente funcionamiento general"                                  },
   {e=>"Vanderbilt - Parent - Full"                                                    ,  s=>"Vanderbilt - Padres - Completa"                                           },
   {e=>"Vanderbilt - Parent - Inattentive Hyperactive"                                 ,  s=>"Vanderbilt - Padres - Falta de atenci�n hiperactivo"                      },
   {e=>"Vanderbilt - Parent - Performance"                                             ,  s=>"Vanderbilt - Padres - Rendimiento"                                        },
   {e=>"Vanderbilt - Parent - Co-morbidities"                                          ,  s=>"Vanderbilt - Padres - Co-morbilidades"                                    },
   {e=>"Parent health question module (nutrition stud"                                 ,  s=>"Padre m�dulo cuesti�n de salud (esp�rrago nutrici�n"                      },
   {e=>"DEES"                                                                          ,  s=>"DEES"                                                                     },
   {e=>"PedsQL - Parent Report for Toddlers (2-4)"                                     ,  s=>"PedsQL - Calificaciones para Padres de ni�os peque�os (2-4)"              },
   {e=>"PedsQL - Parent Report for Young Children (5-"                                 ,  s=>"PedsQL - Calificaciones para Padres de Ni�os Peque�os (5-"                },
   {e=>"PedsQL - Parent Report for Children (8-12)"                                    ,  s=>"PedsQL - Calificaciones para Padres de Ni�os (8-12)"                      },
   {e=>"PedsQL - Parent Report for Teens (13-18)"                                      ,  s=>"PedsQL - Calificaciones para Padres de Adolescentes (13-18)"              },
   {e=>"ASK - Review ASK"                                                              ,  s=>"ASK - Opiniones ASK"                                                      },
   {e=>"DMC Intake - Previous Evaluations"                                             ,  s=>"DMC ingesta - Las evaluaciones anteriores"                                },
   {e=>"DMC Intake - Diagnoses, Services/treatments"                                   ,  s=>"DMC ingesta - Diagn�sticos, Servicios / tratamientos"                     },
   {e=>"Prior Authorization: Academic Issues"                                          ,  s=>"Autorizaci�n previa: Asuntos Acad�micos"                                  },
   {e=>"Prior Authorization: Previous Testing History"                                 ,  s=>"Autorizaci�n previa: Historial de Pruebas"                                },
   {e=>"Prior Authorization: Medical History"                                          ,  s=>"Autorizaci�n previa: Historia de la Medicina"                             },
   {e=>"Prior Authorization: Diagnosis"                                                ,  s=>"Autorizaci�n previa: Diagn�stico"                                         },
   {e=>"Prior Authorization: Tests going to be Used"                                   ,  s=>"Autorizaci�n previa: Pruebas va a ser utilizado"                          },
   {e=>"DMC Intake - Parent/Caregiver Demographics"                                    ,  s=>"DMC ingesta - padre / cuidador Demograf�a"                                },
   {e=>"DMC Intake - Child Birth History"                                              ,  s=>"DMC ingesta - Ni�o Nacimiento Historia"                                   },
   {e=>"DMC Intake - Child Medical History"                                            ,  s=>"DMC ingesta - Ni�o Historia M�dica"                                       },
   {e=>"DMC Intake - Birth Family Medical History"                                     ,  s=>"DMC ingesta - Nacimiento historia cl�nica familiar"                       },
   {e=>"DMC Intake - Child Developmental History"                                      ,  s=>"DMC ingesta - Ni�o Historia del Desarrollo"                               },
   {e=>"DMC Intake - Child Care/School History"                                        ,  s=>"DMC ingesta - Cuidado de ni�os / Historia de la Escuela"                  },
   {e=>"DMC Intake - History of School Problems"                                       ,  s=>"DMC ingesta - historial de problemas de la Escuela"                       },
   {e=>"DMC Intake Teacher Information"                                                ,  s=>"Informaci�n para el profesor de admisi�n DMC"                             },
   {e=>"DMC Intake Teacher Questionnaire Introduction"                                 ,  s=>"DMC ingesta Maestro Cuestionario Introducci�n"                            },
   {e=>"Intake Educational Questionnaire- Academic Re"                                 ,  s=>"La ingesta Educaci�n cuestionario- acad�mico Re"                          },
   {e=>"Intake-Early childhood screening Assessment"                                   ,  s=>"Evaluaci�n de detecci�n temprana infancia Ingesta-"                       },
   {e=>"Teacher - Patient Overall functioning"                                         ,  s=>"Maestro - Paciente funcionamiento general"                                },
   {e=>"edmc Intake Vanderbilt School Performance"                                     ,  s=>"EDMC ingesta de Vanderbilt Rendimiento de la escuela"                     },
   {e=>"edmc Intake Vanderbilt Learning Problems"                                      ,  s=>"EDMC ingesta de Vanderbilt problemas de aprendizaje"                      },
   {e=>"edmc Intake Vanderbilt Classroom setting"                                      ,  s=>"Un entorno EDMC ingesta de Vanderbilt Aula"                               },
   {e=>"edmc Vanderbilt Teacher Questionnaire"                                         ,  s=>"EDMC Vanderbilt Cuestionario Maestro"                                     },
   {e=>"Child Current symptoms"                                                        ,  s=>"s�ntomas actuales del ni�o"                                               },
   {e=>"Childs Allergies"                                                              ,  s=>"Las alergias Childs"                                                      },
   {e=>"Parent Child Overall Health"                                                   ,  s=>"Padres de Ni�os salud en general"                                         },
   {e=>"Childs General Health"                                                         ,  s=>"De Child Health general"                                                  },
   {e=>"Childs Current School Performance"                                             ,  s=>"Rendimiento de Childs Escuela actual"                                     },
   {e=>"Parent Early ChildHood Screening Assessment"                                   ,  s=>"Padres de ni�os peque�os para evaluaci�n"                                 },
   {e=>"Child Medications"                                                             ,  s=>"Los medicamentos para ni�os"                                              },
   {e=>"eDMC Intake - Vanderbilt - Inattentive Hypera"                                 ,  s=>"EDMC ingesta - Vanderbilt - Falta de atenci�n Hypera"                     },
   {e=>"eDMC Intake - Vanderbilt - Performance"                                        ,  s=>"EDMC ingesta - Vanderbilt - Rendimiento"                                  },
   {e=>"MCHAT 16-30"                                                                   ,  s=>"Mchat 16-30"                                                              },
   {e=>"Medications Input"                                                             ,  s=>"Los medicamentos de entrada"                                              },
   {e=>"Dummy Module"                                                                  ,  s=>"M�dulo simulada"                                                          },
   {e=>"ASK - Child Grade (rough) from userBlobData"                                   ,  s=>"ASK - Grado Ni�o (�spero) de userBlobData"                                },
   {e=>"Nutrition Survey Email Follow-Up Ending"                                       ,  s=>"Nutrici�n Encuesta de correo electr�nico de seguimiento Ending"           },
   {e=>"ASK Vanderbilt - Academic Performance"                                         ,  s=>"ASK Vanderbilt - Rendimiento Acad�mico"                                   },
   {e=>"ASK - General performance"                                                     ,  s=>"ASK - el rendimiento general"                                             },
   {e=>"Caregiver - Introduction"                                                      ,  s=>"Cuidador - Introducci�n"                                                  },
   {e=>"Medications Reconciliation Introduction"                                       ,  s=>"Los medicamentos Reconciliaci�n Introducci�n"                             },
   {e=>"Parent - Outro"                                                                ,  s=>"Padre - Outro"                                                            },
   {e=>"Medications Reconciliation - Outro"                                            ,  s=>"Los medicamentos Reconciliaci�n - Outro"                                  },
   {e=>"Vanderbilt Teacher - Inattentive/Hyperactive"                                  ,  s=>"Maestro de Vanderbilt - Falta de atenci�n / Hiperactividad"               },
   {e=>"Vanderbilt - Teacher - Performance"                                            ,  s=>"Vanderbilt - Maestro - Rendimiento"                                       },
   {e=>"Teacher - Patient Overall  functioning"                                        ,  s=>"Maestro - Paciente funcionamiento general"                                },
   {e=>"Vanderbilt - Teacher Survey - Outro"                                           ,  s=>"Vanderbilt - Profesor de la encuesta - Outro"                             },
   {e=>"Teacher - Introduction"                                                        ,  s=>"Maestro - Introducci�n"                                                   },
   {e=>"End of set - to summary"                                                       ,  s=>"Fin de conjunto - de sumario"                                             },
   {e=>"PSS - Perceived Stress Scale"                                                  ,  s=>"PSS - Percepci�n de Escala de Estr�s"                                     },
   {e=>"Demographics"                                                                  ,  s=>"Demograf�a"                                                               },
   {e=>"TriVox Evaluation - Patient Experience"                                        ,  s=>"Evaluaci�n TriVox - La experiencia del paciente"                          },
   {e=>"TriVox Evaluation - Technology Use"                                            ,  s=>"Evaluaci�n TriVox - Uso de Tecnolog�a"                                    },
   {e=>"TriVox Evaluation - Interim Out-of-pocket Cost"                                ,  s=>"TriVox Evaluaci�n - Provisional Costo fuera de su bolsillo"               },
   {e=>"TriVox Evaluation - Interim Patient Experience"                                ,  s=>"Evaluaci�n TriVox - La experiencia del paciente Provisional"              },
   {e=>"TriVox Evaluation - Visit-Specific"                                            ,  s=>"TriVox Evaluaci�n - Visita-espec�fico"                                    },
   {e=>"PANAS-C"                                                                       ,  s=>"PANAS-C"                                                                  },
   {e=>"PANAS-C-P"                                                                     ,  s=>"PANAS-C-P"                                                                },
   {e=>"Columbia DISC - Child"                                                         ,  s=>"DISC Columbia - Ni�o"                                                     },
   {e=>"Columbia DISC - Parent"                                                        ,  s=>"DISC Columbia - Padres"                                                   },
   {e=>"PGBI"                                                                          ,  s=>"PGBI"                                                                     },
   {e=>"TriVox Evaluation - Consent"                                                   ,  s=>"TriVox Evaluaci�n - Consentimiento"                                       },
   {e=>"Asthma Control Test  (ACT)"                                                    ,  s=>"Prueba de Control del Asma (ACT)"                                         },
   {e=>"Asthma Control Test (ACT) - Parent Report"                                     ,  s=>"Prueba de Control del Asma (ACT) - Informe de Padres"                     },
   {e=>"Subject Age"                                                                   ,  s=>"Sujeto Edad"                                                              },
   {e=>"Add Teachers"                                                                  ,  s=>"A�adir maestros"                                                          },
   {e=>"DMC Intake - Family Info"                                                      ,  s=>"La ingesta DMC - Informaci�n de la familia"                               },
   {e=>"NICU - Modified PPQ"                                                           ,  s=>"NICU - Modificado PPQ"                                                    },
   {e=>"NICU - Modified PHQ"                                                           ,  s=>"NICU - Modificado PHQ"                                                    },
   {e=>"Add Teachers"                                                                  ,  s=>"A�adir maestros"                                                          },
   {e=>"Vanderbilt - Adolescent Self-Report"                                           ,  s=>"Vanderbilt - Adolescente Self Report"                                     },
   {e=>"DEES -Intake - Introduction"                                                   ,  s=>"DEES -Intake - Introducci�n"                                              },
   {e=>"Depression - Parent Core - Introduction"                                       ,  s=>"Depresi�n - Core Padres - Introducci�n"                                   },
   {e=>"Demographics - Income and Insurance"                                           ,  s=>"Demograf�a - Ingresos y Seguros"                                          },
   {e=>"DMC Intake - Concerns and referral info"                                       ,  s=>"DMC ingesta - Las preocupaciones y los datos de referencia"               },
   {e=>"DMC Intake - Past Medications"                                                 ,  s=>"La ingesta DMC - Medicamentos pasado"                                     },
   {e=>"Asthma Questions - Self Report"                                                ,  s=>"Preguntas para el asma - Self Report"                                     },
   {e=>"Asthma Questions - Parent Report"                                              ,  s=>"El asma Preguntas - Reporte del Padre"                                    },
   {e=>"Vanderbilt - Teacher - Adolescent - All"                                       ,  s=>"Vanderbilt - Maestro - Adolescentes - Todos"                              },
   {e=>"Vanderbilt - Teacher - Adolescent - Inattentive/Hyperactive"                   ,  s=>"Vanderbilt - Maestro - Adolescentes - Falta de atenci�n / Hiperactividad" },
   {e=>"Vanderbilt - Teacher - Adolescent - Co-Morbidities"                            ,  s=>"Vanderbilt - Maestro - Adolescentes - comorbilidades"                     },
   {e=>"Vanderbilt - Parent - Parent - All"                                            ,  s=>"Vanderbilt - Padres - Padres - Todos"                                     },
   {e=>"Vanderbilt - Parent - Adolescent - Inattentive"                                ,  s=>"Vanderbilt - Padres - Adolescentes - Falta de atenci�n"                   },
   {e=>"Vanderbilt - Adolescent - Parent - Co-morbidities"                             ,  s=>"Vanderbilt - Adolescentes - Padres - Co-morbilidades"                     },
   {e=>"PANAS-X"                                                                       ,  s=>"PANAS-X"                                                                  },
   {e=>"Vanderbilt - Patient Report - Inattentive"                                     ,  s=>"Vanderbilt - Informe del Paciente - Falta de atenci�n"                    },
   {e=>"Vanderbilt - Patient Report - Comorbidities"                                   ,  s=>"Vanderbilt - Informe del Paciente - comorbilidades"                       },
   {e=>"Depression - Parent Survey - Introduction"                                     ,  s=>"Depresi�n - Encuesta para padres - Introducci�n"                          },
   {e=>"Depression - Patient Survey - Introduction"                                    ,  s=>"Depresi�n - Encuesta del Paciente - Introducci�n"                         },
   {e=>"Depression - Patient Initial Survey - Introdu"                                 ,  s=>"Depresi�n - Paciente inicial de la encuesta - Prese"                      },
   {e=>"Demographics - Patient Report - Patient Age"                                   ,  s=>"Demograf�a - Informe del Paciente - Edad del Paciente"                    },
   {e=>"Vanderbilt - Parent - Adolescent - Performance"                                ,  s=>"Vanderbilt - Padres - Adolescentes - Rendimiento"                         },
   {e=>"Patient self-report - Introduction"                                            ,  s=>"Paciente autoinforme - Introducci�n"                                      },
   {e=>"Patient self-report - Outro"                                                   ,  s=>"Paciente autoinforme - Outro"                                             },
   {e=>"Vanderbilt - Teacher - Adolescent - Performance"                               ,  s=>"Vanderbilt - Maestro - Adolescentes - Rendimiento"                        },
   {e=>"Clinical Global Assessment Scale - Self Report"                                ,  s=>"Escala de Evaluaci�n Cl�nica Global - Self Report"                        },
   {e=>"Vanderbilt - Teacher - Co-morbidities"                                         ,  s=>"Vanderbilt - Maestro - Co-morbilidades"                                   },
   {e=>"Epilepsy - Seizure History"                                                    ,  s=>"Epilepsia - apoderamiento Historia"                                       },
   {e=>"Epilepsy - PEMSQ"                                                              ,  s=>"Epilepsia - PEMSQ"                                                        },
   {e=>"Epilepsy - Visit Information"                                                  ,  s=>"Epilepsia - Visita de la Informaci�n"                                     },
   {e=>"TriVox Evaluation - Self Report - Quarterly Pati"                              ,  s=>"Evaluaci�n TriVox - Self Report - Trimestral Pati"                        },
   {e=>"TriVox Evaluation - Self Report - Post-Visit"                                  ,  s=>"Evaluaci�n TriVox - Self Report - despu�s de la visita"                   },
   {e=>"TriVox Evaluation - Self Report - Demographics"                                ,  s=>"Evaluaci�n TriVox - Self Report - Demograf�a"                             },
   {e=>"TriVox Evaluation - Self Report - Technology U"                                ,  s=>"Evaluaci�n TriVox - Informe Auto - Tecnolog�a U"                          },
   {e=>"TriVox Evaluation - Self Report - Quarterly Co"                                ,  s=>"Evaluaci�n TriVox - Self Report - Trimestral Co"                          },
   {e=>"TriVox Evaluation - Self Report - Assent"                                      ,  s=>"TriVox Evaluaci�n - Self Report - Asentimiento"                           },
   {e=>"TriVox Evaluation - Self Report - Patient Experience"                          ,  s=>"Evaluaci�n TriVox - Self Report - La experiencia del paciente"            },
   {e=>"DMC Intake - Teacher - Introduction"                                           ,  s=>"DMC ingesta - Maestro - Introducci�n"                                     },
   {e=>"DMC Intake - Teacher - Academic Performance"                                   ,  s=>"La ingesta DMC - Maestro - Rendimiento Acad�mico"                         },
   {e=>"DMC Intake - Teacher - Learning Problems"                                      ,  s=>"DMC ingesta - Maestro - Problemas de aprendizaje"                         },
   {e=>"DMC Intake - Teacher - Setting"                                                ,  s=>"DMC ingesta - Maestro - Configuraci�n"                                    },
   {e=>"DMC Intake - Teacher - Services"                                               ,  s=>"DMC ingesta - Profesor - Servicios"                                       },
   {e=>"DMC Intake - Teacher - Outro"                                                  ,  s=>"DMC ingesta - Maestro - Outro"                                            },
   {e=>"Autism - Parent - Care Experience"                                             ,  s=>"El autismo - Experiencia Cuidado - Padres"                                },
   {e=>"Autism - Parent - ASD-PROM"                                                    ,  s=>"El autismo - Padres - ASD-PROM"                                           },
   {e=>"MFQ - Short - Caregiver Report"                                                ,  s=>"MFQ - Corto - Informe del cuidador"                                       },
   {e=>"MFQ - Short - Patient Self-report"                                             ,  s=>"MFQ - Corto - el autoinforme del paciente"                                },
   {e=>"MFQ - Short - Adult Patient Self-report"                                       ,  s=>"MFQ - Pantalones cortos - Adulto autoinforme del paciente"                },
   {e=>"MFQ - Long - Caregiver Report"                                                 ,  s=>"MFQ - Long - Informe del cuidador"                                        },
   {e=>"MFQ - Long - Patient Self-report"                                              ,  s=>"MFQ - Long - autoinforme del paciente"                                    },
   {e=>"MFQ - Long - Adult Patient Self-report"                                        ,  s=>"MFQ - Long - Adulto autoinforme del paciente"                             },
   {e=>"SCARED - Caregiver"                                                            ,  s=>"Scared - cuidador"                                                        },
   {e=>"SCARED - Patient Self-report"                                                  ,  s=>"Scared - autoinforme del paciente"                                        },
   {e=>"ADHD Caregiver - PedsQL Evaluation Module"                                     ,  s=>"El TDAH cuidador - M�dulo de Evaluaci�n PedsQL"                           },
   {e=>"EQ-5D-3L Proxy"                                                                ,  s=>"EQ-5D-3L Proxy"                                                           },
   {e=>"EQ-5D-3L Self"                                                                 ,  s=>"EQ-5D-3L Self"                                                            },
   {e=>"EQ-5D-Y Youth Self-Report"                                                     ,  s=>"EQ-5D-Y Ni�o Autoinforme"                                                 },
   {e=>"TriVox Evaluation"                                                             ,  s=>"Evaluaci�n TriVox"                                                        },
   {e=>"TriVox Evaluation - Self-Report - Consent"                                     ,  s=>"TriVox Evaluaci�n - Autoinforme - Consentimiento"                         },
   {e=>"Survey Summary Ask"                                                            ,  s=>"Resumen Encuesta Pregunta"                                                },
   {e=>"DMC Intake - Caregiver - Outro"                                                ,  s=>"DMC ingesta - cuidador - Outro"                                           },
   {e=>"Vanderbilt - Caregiver - Outro"                                                ,  s=>"Vanderbilt - cuidador - Outro"                                            },
   {e=>"Autism - Caregiver Survey - Outro"                                             ,  s=>"El autismo - El cuidador de la encuesta - Outro"                          },
   {e=>"Autism - Caregiver Barriers to Care Survey - Outro"                            ,  s=>"El autismo - Barreras a la atenci�n del cuidador de la encuesta - Outro"  },
   {e=>"ADHD - Caregiver - Visit-Based Survey - Outro"                                 ,  s=>"El TDAH - cuidador - Visita basada en encuestas - Outro"                  },
   {e=>"Asthma - Parent Surveys - Outro"                                               ,  s=>"El asma - encuestas de los padres - Outro"                                },
   {e=>"Asthma - Patient Self-Report Survey - Outro"                                   ,  s=>"El asma - Informe del paciente mismo Encuesta - Outro"                    },
   {e=>"ADHD - Caregiver - Medications Reconciliation Survey - Outro"                  ,  s=>"El TDAH - cuidador - Medicamentos Reconciliaci�n Encuesta - Outro"        },
   {e=>"TriVox Common Core - Teacher - Outro"                                          ,  s=>"TriVox Common Core - Maestro - Outro"                                     },
   {e=>"Depression - Parent Initial Survey - Outro"                                    ,  s=>"Depresi�n - Padres inicial de la encuesta - Outro"                        },
   {e=>"TriVox Common Core - Patient - Outro"                                          ,  s=>"TriVox Common Core - Paciente - Outro"                                    },
   {e=>"TriVox Common Core - Parent - Outro"                                           ,  s=>"TriVox Common Core - Padres - Outro"                                      },
   {e=>"Depression - Caregiver - Visit-based and Manual - Outro"                       ,  s=>"Depresi�n - cuidador - a base de Visita y Manual - Outro"                 },
   {e=>"Epilepsy - Parent Survey - Outro"                                              ,  s=>"Epilepsia - Encuesta para padres - Outro"                                 },
   {e=>"Depression - Patient - Initial TriVox Survey - Outro"                          ,  s=>"Depresi�n - Paciente - Encuesta TriVox inicial - Outro"                   },
   {e=>"Epilepsy - Visit-Based - Parent Survey - Outro"                                ,  s=>"Epilepsia - Visita base-- Encuesta para padres - Outro"                   },
   {e=>"ADHD - Patient self-report Survey - Outro"                                     ,  s=>"El TDAH - autoinforme del paciente Encuesta - Outro"                      },
   {e=>"Depression - Patient - Visit-Based Survey - Outro"                             ,  s=>"Depresi�n - Paciente - Visita basada en encuestas - Outro"                },
   {e=>"ADHD - Patient self-report - Visit-based Survey - Outro"                       ,  s=>"El TDAH - autoinforme del paciente - Visita a base de Encuesta - Outro"   },
   {e=>"Asthma - School Nurse Report"                                                  ,  s=>"El asma - Informe enfermera de la escuela"                                },
   {e=>"School Nurse - Intro"                                                          ,  s=>"Enfermera de la escuela - Intro"                                          },
   {e=>"School Nurse - Outro"                                                          ,  s=>"Enfermera de la escuela - Outro"                                          },
   {e=>"TriVox Evaluation - Self Report - Consent"                                     ,  s=>"Evaluaci�n TriVox - Self Report - Consentimiento"                         },
   {e=>"Anxiety - Caregiver - Outro"                                                   ,  s=>"Ansiedad - cuidador - Outro"                                              },
   {e=>"Anxiety - Patient Self-Report - Outro"                                         ,  s=>"Ansiedad - Informe del paciente mismo - Outro"                            },
   {e=>"Epilepsy - Teacher - Seizure History"                                          ,  s=>"Epilepsia - Maestro - apoderamiento Historia"                             },
   {e=>"Epilepsy - Teacher - Outro"                                                    ,  s=>"Epilepsia - Maestro - Outro"                                              },
   {e=>"Standalone Vanderbilt - Caregiver - Intro"                                     ,  s=>"Independiente de Vanderbilt - cuidador - Intro"                           },
   {e=>"Standalone Vanderbilt - Teacher - Intro"                                       ,  s=>"Independiente de Vanderbilt - Maestro - Intro"                            },
   {e=>"Standalone Vanderbilt - Patient Self-Report - Intro"                           ,  s=>"Independiente de Vanderbilt - Informe del paciente mismo - Intro"         },
   {e=>"Child Grade"                                                                   ,  s=>"Grado Ni�o"                                                               },
   {e=>"DMC Intake - Teacher - Early Childhood - Academic Readiness"                   ,  s=>"La ingesta DMC - Maestro - Primera Infancia - Preparaci�n Acad�mica"      },
   {e=>"DMC Intake - Teacher - Early Childhood - Screening Assessment"                 ,  s=>"La ingesta DMC - Maestro - Primera Infancia - evaluaci�n selectiva"       },
   {e=>"Asthma Control Test - Proxy Report"                                            ,  s=>"Prueba de Control del Asma - Informe de proxy"                            },
   {e=>"Question Type Demonstration"                                                   ,  s=>"Tipo de pregunta de demostraci�n"                                         },
   {e=>"Pilinidal Care - New Patient"                                                  ,  s=>"Cuidado Pilinidal - Nuevo Paciente"                                       },
   {e=>"Pilonidal Care - Follow-Up"                                                    ,  s=>"Cuidado pilonidal - Seguimiento"                                          },
   {e=>"Pilonidal Care - Quality of Life"                                              ,  s=>"Cuidado pilonidal - Calidad de Vida"                                      },
   {e=>"Pilonidal Care - Patient Experience"                                           ,  s=>"Cuidado pilonidal - La experiencia del paciente"                          },
   {e=>"M-CHAT-R"                                                                      ,  s=>"M-CHAT-R"                                                                 },
   {e=>"Standalone PedsQL - Caregiver - Outro"                                         ,  s=>"Independiente PedsQL - cuidador - Outro"                                  },
   {e=>"ASD-PROM Consent"                                                              ,  s=>"ASD-PROM Consentimiento"                                                  },
   {e=>"Neonatal Breathing"                                                            ,  s=>"La respiraci�n neonatal"                                                  },
   {e=>"TRACK Test"                                                                    ,  s=>"Pruebas de la v�a"                                                        },
   {e=>"Preventive Cardiology Lifestyle Screener "                                     ,  s=>"Cardiolog�a Preventiva estilo de vida Screener"                           },
   {e=>"Preventive Cardiology Lifestyle Screener "                                     ,  s=>"Cardiolog�a Preventiva estilo de vida Screener"                           },
   {e=>"Patient Health Questionnaire (PHQ-9) Self Report"                              ,  s=>"Cuestionario de Salud del Paciente (PHQ-9) Informe Auto"                  },
   {e=>"Cath Lab Parent Module"                                                        ,  s=>"M�dulo de Padres Cath Lab"                                                },
   {e=>"Cath Lab Parent Module"                                                        ,  s=>"M�dulo de Padres Cath Lab"                                                },
   {e=>"Cath Lab Nurse Module"                                                         ,  s=>"M�dulo enfermera Cath Lab"                                                },
   {e=>"Cath Lab Parent Module"                                                        ,  s=>"M�dulo de Padres Cath Lab"                                                },
   {e=>"TriVox Epilepsy Seizure Action Plan - Consent"                                 ,  s=>"Plan de Acci�n TriVox epilepsia de ataque - Consentimiento"               },
   {e=>"TriVox Epilepsy Seizure Action Plan - Consent"                                 ,  s=>"Plan de Acci�n TriVox epilepsia de ataque - Consentimiento"               }
   );


my $STATS = {};

my $DEFAULT_ADMIN_ID = 0000;

MAIN:
   $| = 1;
   ArgBuild("*^test *^adminid *^host= *^username= *^password= ^help *^debug");

   ArgParse(@ARGV) or die ArgGetError();
   ArgAddConfig() or die ArgGetError();

   Usage() if ArgIs("help");

   AddUiFields();
   print "Done.\n";
   exit(0);


sub AddUiFields
   {
   my @fields = @FIELDS;

   Connection("onlineadvocate");

   foreach my $field (@fields)
      {
      my $id = GetOrAddUiField($field->{e});
      AddLangUiIfNeeded($field->{e},$id,1804);
      AddLangUiIfNeeded($field->{s},$id,5912);
      }
   }

sub GetOrAddUiField
   {
   my ($field) = @_;

   my $rec = FetchRow("SELECT * from uifields where itemName='$field'");
   return $rec->{id} if $rec && $rec->{id};

   if (ArgIs("test"))
      {
      print "INSERT INTO uifields(itemName) VALUES ('$field')\n";
      return 0;
      }
   ExecSQL("INSERT INTO uifields(itemName) VALUES (?)", $field);

   return InsertId();
   }

sub AddLangUiIfNeeded
   {
   my ($field, $uiid, $langid) = @_;

   my $rec = FetchRow("SELECT * from langui where uiId=$uiid and langId=$langid");
   return $rec->{id} if ($rec && $rec->{id});

   my $adminid = ArgIs("adminid") ? ArgGet("adminid") : $DEFAULT_ADMIN_ID;

   if (ArgIs("test"))
      {
      print "INSERT INTO langui(uiId, langId, value, adminUserId, confirmed) VALUES ($uiid, $langid, '$field', $adminid, 'NO')\n";
      return 0;
      }
   my $sql = "INSERT INTO langui(uiid, langId, value, adminUserId, confirmed) VALUES (?, ?, ?, ?, 'NO')";
   ExecSQL($sql, $uiid, $langid, $field, $adminid);
   return InsertId();
   }


sub Usage
   {
   print Template("usage");
   exit(0);
   }

sub Template
   {
   my ($key, %data) = @_;

   state $templates = InitTemplates();

   my $template = $templates->{$key};
   $template =~ s{\$(\w+)}{exists $data{$1} ? $data{$1} : "\$$1"}gei;
   return $template;
   }

sub InitTemplates
   {
   my $templates = {};
   my $key = "nada";
   while (my $line = <DATA>)
      {
      my ($section) = $line =~ /^\[(\S+)\]/;
      $key = $section || $key;
      $templates->{$key} = ""      if $section;
      $templates->{$key} .= $line  if !$section;
      }
   return $templates;
   }

__DATA__

[usage]
AddUiFields.pl - Add ui fields

USAGE: AddUiFields.pl [options] file

WHERE: 
   [options] are one or more of:
      -help .......... This help
      -list .......... list languages
      -language=name . Set the language to generate
      -adminid=id .... Set the Trivox adminId for new records (9999)
      -apikey=key .... Set the Google API key (craigs key)
      -proxy=proxy ... Set the proxy (or use env: http_proxy)
      -host=foo ...... Set the mysqlhost (localhost)
      -username=foo .. Set the mysqlusername (avocate)
      -password=foo .. Set the mysqlpassword (****************)
      -debug ......... Show stuff.
      -test .......... dont actually insert new stuff to the db
   file is a text file containing a list of new uifields, 1 per line

Examples:
   AddUiFields.pl -list
      List all possible languages that you can specify

   AddUiFields.pl -language=spanish newfields.txt

   AddUiFields.pl -language=german -proxy="http://foo.com:3128" -apikey=AIzaSyA7HOINCmxY new.lst

   set http_proxy=http://proxy.tch.harvard.edu:3128
   AddLanguage.pl -language=italian -username=advocate -pass=puppies -adminid=1234 a.o
[fini]
