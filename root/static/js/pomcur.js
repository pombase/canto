$(document).ready(function() {
  $(".sect .sect-title").each(function(i) {
    $(this).click(function() {
      $(this).next().toggle();
      $(this).toggleClass('undisclosed-title');
      $(this).toggleClass('disclosed-title');
      return false;
    });
    if ($(this).is(".undisclosed-title")) {
      $(this).next().hide();
    } else {
      $(this).next().show();
    }
  })
});

var pomcur = {
  ontology_complete_url : application_root + '/ws/lookup/go/component',

  use_term_data : function(data) {
    $('#ferret-term-definition').text(data[0].definition);

    var children = data[0].children;
    var children_html = '';

    $.each(children, function(idx, child) {
      children_html += '<li>' + child.name + ' (' + child.id + ')</li>';
    });

    $('#ferret-term-children').html($('<ul/>').append($(children_html)));
  },

  term_selected : function() {
    var term_id = $('#ferret-term-id').val();
    if (term_id) {
      $.ajax({
        url: pomcur.ontology_complete_url,
        data: { term: term_id, def: 1, children: 1 },
        dataType: 'json',
        success: pomcur.use_term_data
      });
    }
  },

  set_term : function(term) {
    $('#ferret-term-id').val(term.id);
    $('#ferret-term-id-display').text(term.id);
    $('#ferret-term-entry').val(term.name);
    $('#ferret-term-details').show();
  }
};


$(document).ready(function() {
  $( "#ferret-term-entry" ).autocomplete({
    minLength: 2,
    source: pomcur.ontology_complete_url,
    focus: function(event, ui) {
      $('#ferret-term-entry').val(ui.item.name);
      return false;
    },
    select: function(event, ui) {
      pomcur.set_term(ui.item);
      return false;
    },
    close: pomcur.term_selected
  })
  .data( "autocomplete" )._renderItem = function( ul, item ) {
    return $( "<li></li>" )
      .data( "item.autocomplete", item )
      .append( "<a>" + item.name + " <span class='term-id'>(" + item.id + ")</span></a>" )
      .appendTo( ul );
  };
});

