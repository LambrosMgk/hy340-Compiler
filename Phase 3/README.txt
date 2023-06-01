Se sugkrish me perusi ebgala ola ta stacks pou eixa gia break continue klp kai allaxa ligo tous kanones sou synaktikou
mazi me thn patchLabel wste na meiwsw ta polla xexwrista stacks pou eixa

Uparxei makefile pou me "make all" ftiaxnei to parser (.exe)

exw kapoia themata me ta objects kai kapoia print sta quads, den prolaba na kanw polla test

notes : 

(fixed) backpatch2 lathos label se petaei sto 9 anti gia to 7, des backpatch

(fixed) p3t_assignments_objects exw ligotera emits 32 anti gia 37

(fixed) p3t_basic_expr uminus, des thn proteraiothta kai ta quads tou okeanos, kanonika paei ws a-- -> lvalue -- -> expr - (++lvalue -> expr)

(fixed) p3t_flow_control_error, break continue den petane error an balw se comments to return sthn grammh 6

(fixed) p3t_object_creation_expr, des to funcstart (label 40 prepei na einai)

(done) logika swsto alla des to p3t_relational.asc

changes after submit :

sto al.l ebaza tis int times sto antistoixo pedio int sto union tou alpha_yy pws kai gia to double, tha eprepe na ta exw ola
sto double pedio kai gia auto den ta ektypwna sta quads (exw mono ena geniko numConst kai den xexwrizw int kai double)

allaxa thn seira twn orismatwn se merika if_eq emits 

allaxa to jump label number gia ta functions dioti phdouse panw to funcend label enw eprepe na paei sto akrivws epomeno

ebala emit sto call <-  call Lparenthesis elist Rparenthesis pou xexasa

sundesa kai to method call kanona pou eixa xexasei gia ton opoio prosthesa ena struct method call giati den ithela na ftiaxw kai na 
tropooihsw ena expr struct px setarrontas toy kapoio value gia na katalabw oti einai apo methodcall rule

allaxa thn seria ton tablegetelem emits

sto primary <- lvalue prosthesa emit if table item

prostesa metablhth openloops gia na ftiaxw to p3t_flow_control_error, thn midenizw kathe fora pou mpainw se func kai
thn auxwmeiwno kathe fora sto loop statement, logika den me noiazei na krataw prohgoumenes times mias kai exw oloklhrw loop stack

sto al.l o kanonas operator palia eixe "-"+| to opoio tou elege 1 ews apeira '-' opote mporouse na parei 3 sthn seira to opoio den einai
kapoio legit operator, afairesa to '+' opote twra o kanonas leei pws mporei na dei mono ena '-'.