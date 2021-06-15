use DBI;
use DBD::mysql;

MAIN:
   my $db      = Connect("questionnaires");
   my $MODULES = FetchHash($db, "id", "select * from modules");

   ShowLegend();
   ShowSurveys($db);
   exit(0);


sub ShowSurveys
   {
   my ($db) = @_;

   my $surveys = FetchArray($db, "select * from sets order by id");
   map{ShowSurvey($db, $_)} @{$surveys};
   print "(" . scalar @{$surveys} . " surveys)\n";
   }


# use setflowdefaulttargets and setflowevaluations to track down the modules in a set
#
sub ShowSurvey
   {
   my ($db, $survey) = @_;

   print "Survey $survey->{id} : $survey->{name}\n";

   my $modulemap->{$survey->{firstModuleId}} = 1;

   # load setflowdefaulttargets as an array ordered by id
   my $sqld = "select * from setflowdefaulttargets where setId = $survey->{id}";
   my $defaulttargets = FetchArray($db, $sqld);

   # load setflowevaluations as a hash keyed by moduleId
   my $sqle = "select * from setflowevaluations where setId = $survey->{id}";
   my $evaltargets = FetchHash($db, "moduleId", $sqle);

   foreach my $defaulttarget (@{$defaulttargets})
      {
      my $moduleid  = $defaulttarget->{moduleId};
      my $defaultid = $defaulttarget->{targetModuleId};
      my $evalid    = $evaltargets->{$moduleid} ? $evaltargets->{$moduleid}->{targetModuleId} : 0;

      $modulemap->{$moduleid } = 1;
      $modulemap->{$defaultid} = 1;
      $modulemap->{$evalid   } = 1;
      }
   foreach my $moduleid (sort {$a<=>$b} keys %{$modulemap})
      {
      next unless $moduleid;
      next if $moduleid == 2;
      print "   " . ModuleName($moduleid) . "\n";
      }
   print "--------------------------------------------------\n\n";
   }


sub ShowFlowExpression
   {
   my ($db, $evaluationid) = @_;

   my $sqld = "select * from setflowtokens where setFlowEvaluationId = $evaluationid order by `order`";
   my $tokens = FetchArray($db, $sqld);

   return "(" . join(" ", map{TokenString($_)} @{$tokens}) . ")";
   }

sub TokenString
   {
   my ($token) = @_;
                
   return $token->{token} eq "BLOCK_OPEN"                  ? "("  :
          $token->{token} eq "BLOCK_CLOSE"                 ? ")"  :
          $token->{token} eq "AND"                         ? "&"  :
          $token->{token} eq "OR"                          ? "|"  :
          $token->{token} eq "NOT"                         ? "~"  :
          $token->{token} eq "EQUALS"                      ? "="  :
          $token->{token} eq "NOT_EQUALS"                  ? "!=" :
          $token->{token} eq "LESS_THAN"                   ? "<"  :
          $token->{token} eq "LESS_THAN_OR_EQUAL_TO"       ? "<=" :
          $token->{token} eq "GREATER_THAN"                ? ">"  :
          $token->{token} eq "GREATER_THAN_OR_EQUAL_TO"    ? ">=" :
          $token->{token} eq "PLUS"                        ? "+"  :
          $token->{token} eq "MINUS"                       ? "-"  : 
          $token->{token} eq "INTEGER"                     ? $token->{reference1} : 
          $token->{token} eq "DECIMAL"                     ? $token->{reference1} : 
          $token->{token} eq "BOOLEAN"                     ? $token->{reference1} : 
          $token->{token} eq "STRING"                      ? $token->{reference1} : 
          $token->{token} eq "USER_STUDY_BLOB_DATA"        ? $token->{reference1} : 
          $token->{token} eq "USER_RELATIONSHIP_BLOB_DATA" ? $token->{reference1} : 
          $token->{token} eq "QUESTION_AND_MODULE"         ? "Q&M[$token->{reference1}][$token->{reference2}]" : 
          $token->{token} eq "CALCULATION_AND_MODULE"      ? "C&M[$token->{reference1}][$token->{reference2}]" : 
                                                             $token->{token};
   }



# given a module id return the module id and name as a string:  
#         102 -> [102]Caregiver - Introduction
#
sub ModuleName
   {
   my ($id, $size) = @_;

   $size ||= 50;
   return $MODULES->{$id} ? sprintf("Module %03d : %-*s", $id, $size, $MODULES->{$id}->{name}) : "*module ($id) undefined*";
   }

sub NumStr
   {
   my ($val, $size) = @_;

   $size ||= 3;
   return sprintf("[%*d]", $size, $val);
   }


#----------------------------------------------------------------
sub ShowSurveyGraph
   {
   my ($surveys, $id) = @_;

   my $survey  = SelectSurvey($surveys, $id);

   DumpGraph ($survey); # debug output
   DumpLayout($survey); # debug output

   #PrintGraph ($survey, $layout);
   }


# get the survey data
# ok, what we have is the survey, and connectors in the module node tree
# from this data, we want to build the nodes and the tree
#
#
sub SelectSurvey
   {
   my ($surveys, $id) = @_;

   my $survey;
   map{$survey = $_ if $_->{id} == $id} @{$surveys};
   return {} unless $survey;

   # load setflowdefaulttargets as an array ordered by id
   my $sqld = "select * from setflowdefaulttargets where setId = $survey->{id}";
   my $defs = FetchHash($db, "moduleId", $sqld);

   # load setflowevaluations as a hash keyed by moduleId
   my $sqle = "select * from setflowevaluations where setId = $survey->{id}";
   my $alts = FetchHash($db, "moduleId", $sqle);

   $survey->{graph}  = GenerateGraph ($survey->{firstModuleId}, 0, 0, $defs, $alts);

   $survey->{layout} = [];
   GenerateLayout($survey->{graph}, $survey->{layout});

   return $survey;
   }

# generate a layout for the nodes
#
sub GenerateGraph
   {
   my ($id, $column, $depth, $defs, $alts) = @_;

   return undef unless $id; 

   my $def = $defs->{$id};
   $def->{visited} = 1 if $def;

   my $alt = $alts->{$id};
   $alt->{visited} = 1 if $alt;

   my $def_depth = $depth - ($alt ? 1 : 0);

   my $node = {id     => $id    ,
               column => $column,
               depth  => $depth ,
               def    => GenerateGraph($def->{targetModuleId}, $column+1, $def_depth, $defs, $alts),
               alt    => GenerateGraph($alt->{targetModuleId}, $column+1, $depth+1  , $defs, $alts)
              };
   return $node;
   }

sub DumpGraph
   {
   my ($survey) = @_;

   print "---------------graph dump---------------\n";
   DumpGraphNode($survey->{graph});
   print "----------------------------------------\n";
   }

sub DumpGraphNode
   {
   my ($node) = @_;

   return unless $node;
   print "[$node->{id},$node->{column},$node->{depth}]\n";
   DumpGraphNode($node->{def});
   DumpGraphNode($node->{alt});
   }


sub GenerateLayout
   {
   my ($node, $layout) = @_;

   return unless $node;
   push @{$layout->[$node->{column}]}, $node;
   GenerateLayout($node->{def}, $layout);
   GenerateLayout($node->{alt}, $layout);
   }

sub DumpLayout
   {
   my ($survey) = @_;

   my $layout = $survey->{layout};

   print "---------------layout dump---------------\n";
   foreach my $col (@{$layout})
      {
      print "-----\n";
      foreach my $node (@{$col})
         {
         print sprintf ("id:%3d, col:%2d, depth:%2d", $node->{id},$node->{column},$node->{depth});

         print "[$node->{id},$node->{column},$node->{depth}]\n";
         }
      }
   print "----------------------------------------\n";
   }



#----------------------------------------------------------------

sub Connect
   {
   my ($database) = @_;

   return DBI->connect("DBI:mysql:host=localhost;database=$database;user=craig;password=a") or die "cant connect to $database";
   }

sub FetchArray
   {
   my ($database, $sql) = @_;

   my $sth = $db->prepare ($sql) or return undef;
   $sth->execute ();
   my $results = $sth->fetchall_arrayref({});
   $sth->finish();
   return $results;
   }


sub FetchHash
   {
   my ($database, $key, $sql) = @_;

   my $sth = $db->prepare ($sql) or return undef;
   $sth->execute ();
   my $results = $sth->fetchall_hashref($key);
   $sth->finish();
   return $results;
   }

sub ShowLegend
   {
   print "Survey # : Survey Description (first module id and name)\n";
   print "   [module id]module name  -(d for setflowdefaulttarget)->  [target module id]target module name\n";
   print "   [module id]module name  -(e for setflowevaluations)->    [target module id]target module name (tokens)\n";
   print "-------------------------------------------------------------------------------------------------\n";
   print "-------------------------------------------------------------------------------------------------\n\n";
   }


